import logging
import sys
import os
from pythonjsonlogger import jsonlogger

_logging_initialized = False

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
