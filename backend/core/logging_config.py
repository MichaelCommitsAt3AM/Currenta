import logging
import sys
import os
from typing import Optional
from pythonjsonlogger import jsonlogger

from .log_sink import PostgresLogHandler

_logging_initialized = False
_db_log_handler: Optional[PostgresLogHandler] = None

def setup_logging():
    """
    Configures structured JSON logging for production.
    In development (or if LOG_FORMAT=text), falls back to a human-readable format.
    """
    global _logging_initialized
    if _logging_initialized:
        return

    log_format = os.environ.get("LOG_FORMAT", "json").lower()
    log_level = os.environ.get("LOG_LEVEL", "INFO").upper()

    handler = logging.StreamHandler(sys.stdout)

    if log_format == "json":
        # Structured JSON formatter for production
        formatter = jsonlogger.JsonFormatter(
            fmt="%(asctime)s %(levelname)s %(name)s %(message)s",
            datefmt="%Y-%m-%dT%H:%M:%SZ"
        )
    else:
        # Standard readable formatter for local development
        formatter = logging.Formatter(
            fmt="%(asctime)s [%(levelname)s] %(name)s: %(message)s"
        )

    handler.setFormatter(formatter)

    # Configure the root logger
    root_logger = logging.getLogger()
    root_logger.setLevel(log_level)
    
    # Thoroughly remove all existing handlers from the root logger
    # and also from uvicorn loggers which sometimes have their own.
    for logger_name in [None, "uvicorn", "uvicorn.error", "uvicorn.access", "fastapi"]:
        l = logging.getLogger(logger_name)
        for h in l.handlers[:]:
            l.removeHandler(h)
        l.propagate = True # Ensure they all bubble up to the root where our handler is

    root_logger.addHandler(handler)
    _logging_initialized = True

    # Silence some noisy third-party loggers
    logging.getLogger("uvicorn.access").setLevel(logging.WARNING)
    logging.getLogger("httpx").setLevel(logging.WARNING)
    logging.getLogger("asyncio").setLevel(logging.WARNING)


def attach_db_log_handler(service_name: str, get_pool) -> PostgresLogHandler:
    """
    Adds the app_logs Postgres sink to the root logger. Called separately from
    setup_logging() (and after it) because the DB pool isn't ready until the
    app's lifespan/startup runs — `get_pool` is a zero-arg callable so the
    handler can pick up the pool once it exists rather than needing it at
    construction time.
    """
    global _db_log_handler
    if _db_log_handler is not None:
        return _db_log_handler

    level_name = os.environ.get("APP_LOG_DB_LEVEL", "WARNING").upper()
    level = getattr(logging, level_name, logging.WARNING)

    handler = PostgresLogHandler(service_name=service_name, get_pool=get_pool, level=level)
    handler.setFormatter(logging.Formatter())  # only used for exc_text formatting
    handler.start()

    logging.getLogger().addHandler(handler)
    _db_log_handler = handler
    return handler


async def stop_db_log_handler():
    global _db_log_handler
    if _db_log_handler is not None:
        logging.getLogger().removeHandler(_db_log_handler)
        await _db_log_handler.stop()
        _db_log_handler = None
