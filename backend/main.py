import os
from dotenv import load_dotenv

# Load environment variables before any other local imports
load_dotenv()

from contextlib import asynccontextmanager
from fastapi import FastAPI
import asyncpg
from slowapi import _rate_limit_exceeded_handler
from slowapi.errors import RateLimitExceeded
from uvicorn.middleware.proxy_headers import ProxyHeadersMiddleware

from .services.scheduler import start_scheduler, stop_scheduler
from .core.security import limiter
from .api import feed, ingest, chat

# Global database pool
db_pool = None

import asyncio

@asynccontextmanager
async def lifespan(app: FastAPI):
    global db_pool
    # Diagnostics: Check env loading
    loaded_keys = [k for k in ["DATABASE_URL", "SUPABASE_URL", "ADMIN_API_KEY"] if os.environ.get(k)]
    print(f"Lifespan startup: Loaded keys: {loaded_keys}")

    # Initialize the database connection pool using asyncpg
    database_url = os.environ.get("DATABASE_URL")
    if database_url:
        try:
            print("Connecting to PostgreSQL...")
            # Added a timeout to prevent hanging the entire app startup
            # statement_cache_size=0 is REQUIRED for pgbouncer (Supabase) in transaction mode
            db_pool = await asyncio.wait_for(
                asyncpg.create_pool(
                    dsn=database_url, 
                    ssl='require',
                    statement_cache_size=0
                ),
                timeout=10.0
            )
            app.state.db_pool = db_pool
            print("Connected to PostgreSQL using asyncpg pool.")
        except asyncio.TimeoutError:
            print("ERROR: Connection to PostgreSQL timed out after 10s. Check your DATABASE_URL and network.")
        except Exception as e:
            print(f"ERROR: Failed to connect to database: {e}")
    else:
        print("WARNING: DATABASE_URL not set in environment.")
    
    # Start the background scheduler
    start_scheduler()
    
    yield
    
    # Clean up the pool and background task
    stop_scheduler()
    if db_pool:
        await db_pool.close()
        print("Closed PostgreSQL pool.")

app = FastAPI(title="Currenta Backend", lifespan=lifespan)
# This allows FastAPI to recognize the correctly forwarded protocol (HTTPS) and host from ngrok
app.add_middleware(ProxyHeadersMiddleware)

# Add slowapi limiter to the app state and register the exception handler
app.state.limiter = limiter
app.add_exception_handler(RateLimitExceeded, _rate_limit_exceeded_handler)

# Include the routers for our different API namespaces
app.include_router(feed.router, prefix="/api/feed", tags=["feed"])
app.include_router(ingest.router, prefix="/api/ingest", tags=["ingest"])
app.include_router(chat.router, prefix="/api/chat", tags=["chat"])

@app.get("/")
async def root():
    return {"status": "online", "service": "Currenta Backend Server"}

