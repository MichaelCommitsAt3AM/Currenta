import os
import json
import logging
import logging.config
from dotenv import load_dotenv

# Load environment variables before any other local imports
load_dotenv()

# Bootstrap GCP secrets JSON if running in production
app_config_raw = os.environ.get("APP_CONFIG")
if app_config_raw:
    try:
        config_dict = json.loads(app_config_raw)
        for key, val in config_dict.items():
            os.environ[key] = str(val)
    except json.JSONDecodeError as e:
        print(f"CRITICAL: Failed to parse APP_CONFIG JSON: {e}")

from contextlib import asynccontextmanager
from fastapi import FastAPI, HTTPException, Request
from fastapi.responses import JSONResponse
from fastapi.middleware.cors import CORSMiddleware
from starlette.middleware.base import BaseHTTPMiddleware
import asyncpg
from slowapi import _rate_limit_exceeded_handler
from slowapi.errors import RateLimitExceeded
from uvicorn.middleware.proxy_headers import ProxyHeadersMiddleware
import redis.asyncio as redis
from brotli_asgi import BrotliMiddleware

from .core.logging_config import setup_logging, attach_db_log_handler, stop_db_log_handler
from .core.db import init_db_pool, init_redis, close_connections
import backend.core.db as db_state
from .version import VERSION

# ---------------------------------------------------------------------------
# Logging — configure once at startup
# ---------------------------------------------------------------------------
setup_logging()

from .core.security import limiter, get_client_ip
from .api import feed, ingest, chat, trending, admin, auth, taxonomy
from .version import VERSION
from .services.scheduler import start_scheduler, stop_scheduler

import asyncio

logger = logging.getLogger(__name__)


class SecurityHeadersMiddleware(BaseHTTPMiddleware):
    async def dispatch(self, request, call_next):
        response = await call_next(request)
        response.headers["X-Content-Type-Options"] = "nosniff"
        response.headers["X-Frame-Options"] = "DENY"
        response.headers["Referrer-Policy"] = "no-referrer"
        return response


@asynccontextmanager
async def lifespan(app: FastAPI):
    # Initialize shared connections
    app.state.db_pool = await init_db_pool()
    app.state.redis_client = await init_redis()

    # Attach the app_logs DB sink now that the pool exists (setup_logging()
    # ran at import time, before any pool was available).
    attach_db_log_handler(os.environ.get("SERVICE_NAME", "api"), lambda: db_state.db_pool)

    if ENABLE_INTERNAL_SCHEDULER:
        # Pass the pool and client to the scheduler (simplified)
        start_scheduler()
    else:
        logger.info("Internal scheduler is disabled (ENABLE_INTERNAL_SCHEDULER=False).")

    yield

    await stop_db_log_handler()
    await close_connections()

app = FastAPI(title="Currenta Backend", version=VERSION, lifespan=lifespan)

# --- Middleware stack ---
app.add_middleware(ProxyHeadersMiddleware, trusted_hosts="*")
app.add_middleware(SecurityHeadersMiddleware)

ALLOWED_ORIGINS_RAW = os.environ.get("ALLOWED_ORIGINS", "http://localhost:5500,http://127.0.0.1:5500,http://localhost:3000,http://127.0.0.1:3000,https://hidden-paper-0d93.michaelnjonge905.workers.dev,https://admin.currenta.tech")
ALLOWED_ORIGINS = [o.strip() for o in ALLOWED_ORIGINS_RAW.split(",") if o.strip()]

app.add_middleware(
    CORSMiddleware,
    allow_origins=ALLOWED_ORIGINS,
    allow_credentials=True,
    allow_methods=["GET", "POST", "OPTIONS"],
    allow_headers=["Authorization", "Content-Type", "X-API-Key"],
)
app.add_middleware(BrotliMiddleware, minimum_size=1000)

app.state.limiter = limiter

async def custom_rate_limit_exceeded_handler(request: Request, exc: RateLimitExceeded):
    ip = get_client_ip(request)
    auth = request.headers.get("Authorization")
    user_type = "authenticated" if (auth and auth.startswith("Bearer ")) else "guest"
    logger.warning(f"Rate limit exceeded (429) for {user_type} IP: {ip} at {request.url.path}")
    return _rate_limit_exceeded_handler(request, exc)

app.add_exception_handler(RateLimitExceeded, custom_rate_limit_exceeded_handler)

ENABLE_INTERNAL_SCHEDULER = os.environ.get("ENABLE_INTERNAL_SCHEDULER", "true").lower() == "true"

# --- Routers (Always included in API) ---
app.include_router(feed.router, prefix="/api/feed", tags=["feed"])
app.include_router(ingest.router, prefix="/api/ingest", tags=["ingest"])
app.include_router(chat.router, prefix="/api/chat", tags=["chat"])
app.include_router(trending.router, prefix="/api/trending", tags=["trending"])
app.include_router(admin.router, prefix="/api/admin", tags=["admin"])
app.include_router(auth.router, prefix="/api/auth", tags=["auth"])
app.include_router(taxonomy.router, prefix="/api/taxonomy", tags=["taxonomy"])


@app.get("/")
async def root():
    return {
        "status": "online", 
        "service": "Currenta Backend Server", 
        "backend_version": app.version
    }


@app.get("/health")
async def health_check():
    import time
    from .api.chat import _gemini_client, _vertex_client, LLM_PROVIDER
    from .services.scheduler import scheduler

    report: dict = {}
    overall_ok = True

    pool = getattr(app.state, "db_pool", None)
    if pool:
        try:
            t0 = time.monotonic()
            async with pool.acquire() as conn:
                await conn.fetchval("SELECT 1")
            latency_ms = round((time.monotonic() - t0) * 1000, 1)
            report["database"] = {"status": "ok", "latency_ms": latency_ms}
        except Exception as e:
            logger.error("Health check — DB probe failed: %s", e)
            report["database"] = {"status": "error", "detail": "Query failed"}
            overall_ok = False
    else:
        report["database"] = {"status": "error", "detail": "Pool not initialised"}
        overall_ok = False

    redis_cli = getattr(app.state, "redis_client", None)
    if redis_cli:
        try:
            t0 = time.monotonic()
            await redis_cli.ping()
            latency_ms = round((time.monotonic() - t0) * 1000, 1)
            report["redis"] = {"status": "ok", "latency_ms": latency_ms}
        except Exception as e:
            logger.error("Health check — Redis probe failed: %s", e)
            report["redis"] = {"status": "error", "detail": "Ping failed"}
            overall_ok = False
    else:
        report["redis"] = {"status": "unconfigured", "detail": "REDIS_URL not set or connection failed"}
        overall_ok = False
        
    report["google_ai_studio"] = {"status": "ok" if _gemini_client is not None else "unconfigured"}
    report["google_vertex_ai"] = {"status": "ok" if _vertex_client is not None else "unconfigured"}
    report["gemini"] = report["google_ai_studio"] if LLM_PROVIDER == "gemini" else report["google_vertex_ai"]

    if ENABLE_INTERNAL_SCHEDULER:
        jobs = scheduler.get_jobs()
        report["scheduler"] = {
            "status": "ok" if scheduler.running else "stopped",
            "job_count": len(jobs),
            "jobs": [j.name for j in jobs],
        }
    else:
        report["scheduler"] = {"status": "external"}

    return JSONResponse(
        status_code=200 if overall_ok else 503,
        content={"status": "healthy" if overall_ok else "degraded", "components": report},
    )
