import asyncio
import logging

from backend.core.log_sink import PostgresLogHandler, _redact, _signature, _COMPONENT_RE
from backend.core.logging_config import attach_db_log_handler, stop_db_log_handler


class _FakeConn:
    def __init__(self, sink):
        self.sink = sink

    async def executemany(self, query, rows):
        self.sink.extend(rows)

    async def __aenter__(self):
        return self

    async def __aexit__(self, *exc):
        return False


class _FakePool:
    def __init__(self, sink):
        self.sink = sink

    def acquire(self):
        return _FakeConn(self.sink)


def _isolated_logger(name: str, handler: PostgresLogHandler) -> logging.Logger:
    logger = logging.getLogger(name)
    logger.setLevel(logging.DEBUG)
    logger.handlers.clear()
    logger.addHandler(handler)
    logger.propagate = False
    return logger


def test_component_tag_extracted_from_bracket_prefix():
    m = _COMPONENT_RE.match("[embed_text] Voyage AI rate limit hit (429) and exhausted retries.")
    assert m is not None
    assert m.group(1) == "embed_text"


def test_redact_strips_bearer_tokens_and_jwts():
    text = "Authorization: Bearer abc123.def456-ghi and token=eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiJ4In0.dGVzdHNpZ25hdHVyZQ"
    redacted = _redact(text)
    assert "abc123" not in redacted
    assert "eyJ" not in redacted
    assert "[redacted]" in redacted


def test_signature_collapses_messages_that_differ_only_in_ids():
    sig1 = _signature("Failed to update interest vector for user 3f2504e0-4f89-11d3-9a0c-0305e82c3301: refused")
    sig2 = _signature("Failed to update interest vector for user 9f2504e0-4f89-11d3-9a0c-0305e82c9999: refused")
    assert sig1 == sig2

    sig3 = _signature("Failed to send email to user@example.com: timeout")
    assert sig3 != sig1


def test_emit_drops_non_allowlisted_info_but_keeps_allowlisted_info():
    async def run():
        handler = PostgresLogHandler(service_name="worker", get_pool=lambda: None, level=logging.WARNING)
        logger = _isolated_logger("backend.services.ingestion.test_a", handler)

        logger.info("Feed Session Hit: session=abc cursor=1 items=5")
        assert handler._queue.qsize() == 0

        logger.info("Orchestrator: Starting orchestration for 12 feeds")
        assert handler._queue.qsize() == 1

    asyncio.run(run())


def test_emit_always_keeps_warning_and_above():
    async def run():
        handler = PostgresLogHandler(service_name="api", get_pool=lambda: None, level=logging.WARNING)
        logger = _isolated_logger("backend.api.chat.test_b", handler)

        logger.warning("[chat] Gemini API error (attempt 1/3)")
        logger.error("Chat stream error: boom")
        assert handler._queue.qsize() == 2

    asyncio.run(run())


def test_emit_drops_records_from_excluded_loggers():
    async def run():
        handler = PostgresLogHandler(service_name="api", get_pool=lambda: None, level=logging.WARNING)
        logger = _isolated_logger("backend.core.db", handler)

        logger.error("Failed to connect to database")
        assert handler._queue.qsize() == 0

    asyncio.run(run())


def test_emit_recursion_guard_drops_records_during_flush():
    async def run():
        handler = PostgresLogHandler(service_name="api", get_pool=lambda: None, level=logging.WARNING)
        logger = _isolated_logger("backend.api.admin.test_c", handler)

        handler._in_flush = True
        logger.error("should never be queued while flushing")
        assert handler._queue.qsize() == 0
        handler._in_flush = False

    asyncio.run(run())


def test_queue_overflow_drops_oldest_not_newest():
    async def run():
        handler = PostgresLogHandler(service_name="api", get_pool=lambda: None, level=logging.WARNING, max_queue=2)
        logger = _isolated_logger("backend.api.admin.test_d", handler)

        logger.error("first")
        logger.error("second")
        logger.error("third")  # should evict "first"

        assert handler._queue.qsize() == 2
        remaining = [handler._queue.get_nowait()["message"] for _ in range(2)]
        assert remaining == ["second", "third"]

    asyncio.run(run())


def test_flush_writes_batched_rows_to_pool():
    async def run():
        sink = []
        pool = _FakePool(sink)
        handler = PostgresLogHandler(service_name="worker", get_pool=lambda: pool, level=logging.WARNING)
        logger = _isolated_logger("backend.services.trending.test_e", handler)

        logger.error("[Trending-Logger] Failed to write to trending_logs: boom")
        logger.warning("generic warning")
        await handler._flush()

        assert len(sink) == 2
        levels = {row[0] for row in sink}
        assert levels == {"ERROR", "WARNING"}

    asyncio.run(run())


def test_flush_is_noop_when_pool_unavailable():
    async def run():
        handler = PostgresLogHandler(service_name="api", get_pool=lambda: None, level=logging.WARNING)
        logger = _isolated_logger("backend.api.admin.test_f", handler)

        logger.error("no pool yet")
        await handler._flush()  # must not raise

        assert handler._queue.qsize() == 1  # nothing was consumed

    asyncio.run(run())


def test_attach_db_log_handler_is_idempotent_and_stoppable():
    async def run():
        h1 = attach_db_log_handler("api", lambda: None)
        h2 = attach_db_log_handler("api", lambda: None)
        assert h1 is h2
        assert logging.getLogger().handlers.count(h1) == 1

        await stop_db_log_handler()
        assert h1 not in logging.getLogger().handlers

    asyncio.run(run())
