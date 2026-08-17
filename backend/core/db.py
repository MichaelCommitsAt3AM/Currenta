import os
import asyncio
import logging
import asyncpg
import redis.asyncio as redis
from typing import Optional

logger = logging.getLogger(__name__)

db_pool: Optional[asyncpg.Pool] = None
redis_client: Optional[redis.Redis] = None

async def init_db_pool():
    global db_pool
    database_url = os.environ.get("DATABASE_URL")
    if not database_url:
        logger.warning("DATABASE_URL is not set — database features will be unavailable.")
        return None

    max_retries = 5
    base_delay = 2  # seconds

    # Hosted Supabase's pooler requires SSL; the self-hosted stack's `db`
    # container is only reachable over the private docker network and
    # doesn't have SSL configured, so it actively rejects the upgrade.
    ssl_mode = os.environ.get("DB_SSL_MODE", "require")
    ssl_param = False if ssl_mode == "disable" else ssl_mode

    for attempt in range(max_retries):
        try:
            logger.info(f"Connecting to PostgreSQL (Attempt {attempt+1}/{max_retries})...")
            # statement_cache_size=0 is REQUIRED for pgbouncer transaction mode.
            db_pool = await asyncio.wait_for(
                asyncpg.create_pool(
                    dsn=database_url,
                    ssl=ssl_param,
                    statement_cache_size=0,
                    min_size=2,
                    max_size=12,
                    max_inactive_connection_lifetime=300,
                ),
                timeout=10.0
            )
            logger.info("Connected to PostgreSQL (pool min=2, max=12).")
            return db_pool
        except (asyncio.TimeoutError, asyncpg.PostgresError, OSError) as e:
            wait_time = base_delay * (2 ** attempt)
            if attempt < max_retries - 1:
                logger.error(f"Failed to connect to database (attempt {attempt+1}/{max_retries}): {e}. Retrying in {wait_time}s...")
                await asyncio.sleep(wait_time)
            else:
                logger.error(f"Failed to connect to database after {max_retries} attempts: {e}.")
    return None

async def init_redis():
    global redis_client
    redis_url = os.environ.get("REDIS_URL", "redis://localhost:6379")
    try:
        logger.info(f"Connecting to Redis at {redis_url}...")
        redis_client = redis.from_url(redis_url, decode_responses=True)
        await redis_client.ping()
        logger.info("Connected to Redis.")
        return redis_client
    except Exception as e:
        logger.error("Failed to connect to Redis: %s", e)
        redis_client = None
    return None

async def close_connections():
    global db_pool, redis_client
    if db_pool:
        await db_pool.close()
        logger.info("Closed PostgreSQL pool.")
    if redis_client:
        await redis_client.close()
        logger.info("Closed Redis connection.")
