import os
import logging
import logging.config
from dotenv import load_dotenv

# Load environment variables before any other local imports
load_dotenv()

from contextlib import asynccontextmanager
from fastapi import FastAPI, HTTPException
from fastapi.responses import JSONResponse
from fastapi.middleware.cors import CORSMiddleware
from starlette.middleware.base import BaseHTTPMiddleware
import asyncpg
from slowapi import _rate_limit_exceeded_handler
from slowapi.errors import RateLimitExceeded
from uvicorn.middleware.proxy_headers import ProxyHeadersMiddleware
import redis.asyncio as redis

from .services.scheduler import start_scheduler, stop_scheduler
from .core.logging_config import setup_logging
from .core.security import limiter
from .api import feed, ingest, chat, trending
from .version import VERSION

import asyncio

# ---------------------------------------------------------------------------
# Logging — configure once at startup so all modules use structured output
# ---------------------------------------------------------------------------
setup_logging()
logger = logging.getLogger(__name__)


# ---------------------------------------------------------------------------
# Security headers middleware — applied to every response
# ---------------------------------------------------------------------------
class SecurityHeadersMiddleware(BaseHTTPMiddleware):
    async def dispatch(self, request, call_next):
        response = await call_next(request)
        response.headers["X-Content-Type-Options"] = "nosniff"
        response.headers["X-Frame-Options"] = "DENY"
        response.headers["Referrer-Policy"] = "no-referrer"
        return response


# Global database pool and Redis client
db_pool = None
redis_client = None

@asynccontextmanager
async def lifespan(app: FastAPI):
    global db_pool, redis_client

    database_url = os.environ.get("DATABASE_URL")
    if database_url:
        try:
            logger.info("Connecting to PostgreSQL...")
            # min_size/max_size tuned for Supabase PgBouncer in transaction mode.
            # statement_cache_size=0 is REQUIRED for pgbouncer transaction mode.
            db_pool = await asyncio.wait_for(
                asyncpg.create_pool(
                    dsn=database_url,
                    ssl='require',
                    statement_cache_size=0,
                    min_size=2,
                    max_size=8,
                ),
                timeout=10.0
            )
            app.state.db_pool = db_pool
            logger.info("Connected to PostgreSQL (pool min=2, max=8).")
        except asyncio.TimeoutError:
            logger.error("Connection to PostgreSQL timed out after 10s. Check DATABASE_URL and network.")
        except Exception as e:
            logger.error("Failed to connect to database: %s", e)
    else:
        logger.warning("DATABASE_URL is not set — database features will be unavailable.")

    redis_url = os.environ.get("REDIS_URL", "redis://localhost:6379")
    try:
        logger.info(f"Connecting to Redis at {redis_url}...")
        redis_client = redis.from_url(redis_url, decode_responses=True)
        # Test connection
        await redis_client.ping()
        app.state.redis_client = redis_client
        logger.info("Connected to Redis.")
    except Exception as e:
        logger.error("Failed to connect to Redis: %s", e)
        app.state.redis_client = None

    start_scheduler()

    yield

    stop_scheduler()
    if db_pool:
        await db_pool.close()
        logger.info("Closed PostgreSQL pool.")
    if redis_client:
        await redis_client.close()
        logger.info("Closed Redis connection.")

app = FastAPI(title="Currenta Backend", version=VERSION, lifespan=lifespan)

# --- Middleware stack (order matters: outermost = last added) ---

# 1. Trust forwarded headers from reverse proxy / ngrok
app.add_middleware(ProxyHeadersMiddleware)

# 2. Security response headers on every reply
app.add_middleware(SecurityHeadersMiddleware)

# 3. CORS — mobile-only API, so no browser origin is needed.
#    Restrict to your production domain when you have one.
#    For a pure mobile API you can keep allow_origins=[] (no browser CORS needed)
#    but explicit configuration is required to avoid framework defaults.
ALLOWED_ORIGINS = os.environ.get("ALLOWED_ORIGINS", "").split(",")
ALLOWED_ORIGINS = [o.strip() for o in ALLOWED_ORIGINS if o.strip()]
app.add_middleware(
    CORSMiddleware,
    allow_origins=ALLOWED_ORIGINS,  # Set ALLOWED_ORIGINS env var in prod; empty = block browser callers
    allow_credentials=True,
    allow_methods=["GET", "POST"],
    allow_headers=["Authorization", "Content-Type", "X-API-Key"],
)

# --- Rate limiting ---
app.state.limiter = limiter
app.add_exception_handler(RateLimitExceeded, _rate_limit_exceeded_handler)

# --- Routers ---
app.include_router(feed.router, prefix="/api/feed", tags=["feed"])
app.include_router(ingest.router, prefix="/api/ingest", tags=["ingest"])
app.include_router(chat.router, prefix="/api/chat", tags=["chat"])
app.include_router(trending.router, prefix="/api/trending", tags=["trending"])


@app.get("/")
async def root():
    return {
        "status": "online", 
        "service": "Currenta Backend Server", 
        "backend_version": app.version
    }


@app.get("/health")
async def health_check():
    """
    Real dependency health check. Probes each downstream system and returns
    a structured report. HTTP 503 is returned if any critical component fails,
    so load balancers and uptime monitors can act on it correctly.

    Components checked:
      - database  : runs SELECT 1 through an actual pool connection (latency reported)
      - gemini    : verifies GEMINI_API_KEY was loaded and a client was created
      - scheduler : confirms the APScheduler background job is running
    """
    import time
    from .api.chat import _gemini_client, _vertex_client, LLM_PROVIDER
    from .services.scheduler import scheduler

    report: dict = {}
    overall_ok = True

    # ── 1. PostgreSQL — live round-trip query ─────────────────────────────────
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

    # ── 1.5. Redis ────────────────────────────────────────────────────────────
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
        
    # ── 2. Google Generative AI (AI Studio & Vertex) ──────────────────────────
    # Checking both implementations
    report["google_ai_studio"] = {"status": "ok" if _gemini_client is not None else "unconfigured"}
    report["google_vertex_ai"] = {"status": "ok" if _vertex_client is not None else "unconfigured"}
    
    # Backward compatibility for health check consumers
    report["gemini"] = report["google_ai_studio"] if LLM_PROVIDER == "gemini" else report["google_vertex_ai"]

    # ── 3. APScheduler ───────────────────────────────────────────────────────
    jobs = scheduler.get_jobs()
    report["scheduler"] = {
        "status": "ok" if scheduler.running else "stopped",
        "job_count": len(jobs),
        "jobs": [j.name for j in jobs],
    }
    if not scheduler.running:
        overall_ok = False

    return JSONResponse(
        status_code=200 if overall_ok else 503,
        content={
            "status": "healthy" if overall_ok else "degraded",
            "components": report,
        },
    )
