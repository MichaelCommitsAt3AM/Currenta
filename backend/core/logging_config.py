import logging
import sys
import os
from pythonjsonlogger import jsonlogger

def setup_logging():
    """
    Configures structured JSON logging for production.
    In development (or if LOG_FORMAT=text), falls back to a human-readable format.
    """
    log_format = os.environ.get("LOG_FORMAT", "json").lower()
    log_level = os.environ.get("LOG_LEVEL", "INFO").upper()

    handler = logging.StreamHandler(sys.stdout)

    if log_format == "json":
        # Structured JSON formatter for production (ELK, Datadog, CloudWatch)
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
    
    # Remove existing handlers to avoid duplicate logs in environments like Docker or cloud runners
    while root_logger.handlers:
        root_logger.removeHandler(root_logger.handlers[0])
    
    root_logger.addHandler(handler)

    # Silence some noisy third-party loggers
    logging.getLogger("uvicorn.access").setLevel(logging.WARNING)
    logging.getLogger("httpx").setLevel(logging.WARNING)
    logging.getLogger("asyncio").setLevel(logging.WARNING)
