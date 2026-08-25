import asyncio
import hashlib
import logging
import re
import time
from typing import Optional

import asyncpg

# Loggers excluded from the DB sink entirely — mainly to break the recursion
# where a failed flush (asyncpg/db) logs an error that would otherwise be
# queued right back into the same handler.
_EXCLUDED_LOGGERS = ("asyncpg", "backend.core.db", "backend.core.log_sink")

# Below this level, only the allowlisted loggers below are ever queued —
# everything else at INFO/DEBUG is high-volume per-request noise
# (feed sessions, per-article ingestion success) already captured elsewhere
# (ingestion_logs) or not worth the row volume.
_INFO_ALLOWLIST_PREFIXES = (
    "backend.services.scheduler",
    "backend.worker",
    "backend.core.security",
)
_INFO_ALLOWLIST_SUBSTRINGS = (
    "Orchestrator:",
    "[Cleanup]",
    "[admin_query]",
    "Trending score update",
    "[Blocklist]",
)

_COMPONENT_RE = re.compile(r"^\[([^\]]+)\]")
_NORMALIZE_RE = re.compile(
    r"[0-9a-fA-F-]{8,}|https?://\S+|\b\d+(\.\d+)?\b|'[^']*'|\"[^\"]*\""
)

_redact_patterns = [
    re.compile(r"Bearer\s+[A-Za-z0-9\-_.]+", re.IGNORECASE),
    re.compile(r"(apikey|api_key)=[^&\s]+", re.IGNORECASE),
    re.compile(r"eyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}"),  # JWT-shaped
    re.compile(r"service_role[^\s,;]*", re.IGNORECASE),
]


def _redact(text: str) -> str:
    for pattern in _redact_patterns:
        text = pattern.sub("[redacted]", text)
    return text


def _signature(message: str) -> str:
    normalized = _NORMALIZE_RE.sub("#", message)
    return hashlib.sha256(normalized.encode("utf-8", "replace")).hexdigest()[:16]


class PostgresLogHandler(logging.Handler):
    """Batches log records into `app_logs`. Never blocks the caller: emit()
    only formats and enqueues, a background task does the actual insert.

    Fails open — if there's no pool, or a flush fails, logging keeps working
    everywhere else; only this handler's contribution to app_logs is lost.
    """

    def __init__(
        self,
        service_name: str,
        get_pool,
        level: int = logging.WARNING,
        max_queue: int = 5000,
        flush_interval: float = 2.0,
        flush_batch_size: int = 200,
    ):
        # NOTSET on the base Handler itself — level filtering happens inside
        # emit() below, using `level` as `self._min_level`. If we instead set
        # Handler.level=WARNING here, logging.Logger.callHandlers() would
        # filter out INFO records before emit() ever runs, and the INFO
        # allowlist logic below would never get a chance to run.
        super().__init__(level=logging.NOTSET)
        self._min_level = level
        self._service_name = service_name
        self._get_pool = get_pool
        self._queue: "asyncio.Queue" = asyncio.Queue(maxsize=max_queue)
        self._flush_interval = flush_interval
        self._flush_batch_size = flush_batch_size
        self._task: Optional[asyncio.Task] = None
        self._in_flush = False
        self._dropped_since_warning = 0
        self._last_drop_warning = 0.0

    def start(self):
        if self._task is None or self._task.done():
            self._task = asyncio.create_task(self._drain_loop())

    async def stop(self):
        if self._task is not None:
            self._task.cancel()
            try:
                await self._task
            except (asyncio.CancelledError, Exception):
                pass
            self._task = None
        # Best-effort final flush of whatever's left in the queue.
        try:
            await self._flush()
        except Exception:
            pass

    def emit(self, record: logging.LogRecord) -> None:
        if self._in_flush:
            return  # recursion guard: a failure during flush must not re-enter
        if any(record.name == n or record.name.startswith(n + ".") for n in _EXCLUDED_LOGGERS):
            return
        if record.levelno < self._min_level and not self._is_info_allowed(record):
            return

        try:
            row = self._format_row(record)
        except Exception:
            return

        try:
            self._queue.put_nowait(row)
        except asyncio.QueueFull:
            try:
                self._queue.get_nowait()  # drop oldest
            except asyncio.QueueEmpty:
                pass
            try:
                self._queue.put_nowait(row)
            except asyncio.QueueFull:
                pass
            self._dropped_since_warning += 1
            now = time.monotonic()
            if now - self._last_drop_warning > 60:
                self._last_drop_warning = now
                dropped = self._dropped_since_warning
                self._dropped_since_warning = 0
                print(f"[log_sink] app_logs queue full — dropped {dropped} records in the last minute", flush=True)

    def _is_info_allowed(self, record: logging.LogRecord) -> bool:
        if any(record.name == n or record.name.startswith(n + ".") for n in _INFO_ALLOWLIST_PREFIXES):
            return True
        msg = record.getMessage()
        return any(sub in msg for sub in _INFO_ALLOWLIST_SUBSTRINGS)

    def _format_row(self, record: logging.LogRecord) -> dict:
        message = _redact(record.getMessage())
        component_match = _COMPONENT_RE.match(message)
        component = component_match.group(1) if component_match else None

        exc_text = None
        if record.exc_info:
            exc_text = _redact(self.formatter.formatException(record.exc_info) if self.formatter else logging.Formatter().formatException(record.exc_info))

        return {
            "created_at": None,  # DB default (now()) — clock authority stays on the DB
            "level": record.levelname,
            "level_no": record.levelno,
            "service": self._service_name,
            "logger": record.name,
            "component": component,
            "message": message[:8000],
            "module": record.module,
            "func": record.funcName,
            "line": record.lineno,
            "exc_text": exc_text[:8000] if exc_text else None,
            "signature": _signature(message),
        }

    async def _drain_loop(self):
        while True:
            try:
                await asyncio.sleep(self._flush_interval)
                await self._flush()
            except asyncio.CancelledError:
                raise
            except Exception as e:
                print(f"[log_sink] drain loop error: {e}", flush=True)

    async def _flush(self):
        if self._queue.empty():
            return
        pool = self._get_pool()
        if pool is None:
            return

        rows = []
        while not self._queue.empty() and len(rows) < self._flush_batch_size:
            try:
                rows.append(self._queue.get_nowait())
            except asyncio.QueueEmpty:
                break
        if not rows:
            return

        self._in_flush = True
        try:
            async with pool.acquire() as conn:
                await conn.executemany(
                    """
                    INSERT INTO app_logs
                        (level, level_no, service, logger, component, message,
                         module, func, line, exc_text, signature)
                    VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11)
                    """,
                    [
                        (
                            r["level"], r["level_no"], r["service"], r["logger"],
                            r["component"], r["message"], r["module"], r["func"],
                            r["line"], r["exc_text"], r["signature"],
                        )
                        for r in rows
                    ],
                )
        except (asyncpg.PostgresError, OSError) as e:
            print(f"[log_sink] failed to flush {len(rows)} log rows: {e}", flush=True)
        finally:
            self._in_flush = False


async def cleanup_old_app_logs(db_pool: asyncpg.Pool):
    """Deletes app_logs rows past retention: ERROR/CRITICAL kept longer since
    they're low-volume and are what the grouped-errors admin view depends on
    for trend history; everything else (WARNING and the allowlisted INFO
    lifecycle lines) is higher-volume and short-lived."""
    logger = logging.getLogger(__name__)
    async with db_pool.acquire() as conn:
        deleted = await conn.fetchval(
            """
            WITH d AS (
                DELETE FROM app_logs
                WHERE (level_no >= 40 AND created_at < NOW() - INTERVAL '30 days')
                   OR (level_no < 40 AND created_at < NOW() - INTERVAL '7 days')
                RETURNING 1
            )
            SELECT COUNT(*) FROM d
            """
        )
    logger.info(f"[Cleanup] Deleted {deleted} app_logs rows past retention.")
