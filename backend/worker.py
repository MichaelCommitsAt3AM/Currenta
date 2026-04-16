import asyncio
import logging
import os
from dotenv import load_dotenv

# Load environment variables
load_dotenv()

from .core.logging_config import setup_logging
from .core import db
from .services.ingestion import orchestrate_sync_wrapper
from .services.trending import update_trending_scores
from apscheduler.schedulers.asyncio import AsyncIOScheduler

# Configure logging
setup_logging()
logger = logging.getLogger(__name__)

async def run_ingestion_and_trending():
    """Wrapper to run scraping followed immediately by ranking/trending."""
    logger.info("--- Starting Scheduled Ingestion Cycle ---")
    await orchestrate_sync_wrapper()
    logger.info("Ingestion complete. Starting post-sync trending update...")
    await update_trending_scores(db.db_pool, db.redis_client)
    logger.info("--- Ingestion and Trending Cycle Complete ---")

async def main():
    logger.info("Starting Currenta Ingestion Worker...")
    
    # Initialize connections
    active_pool = await db.init_db_pool()
    await db.init_redis()
    
    if not active_pool:
        logger.error("Failed to initialize database pool. Worker exiting.")
        return

    # Initialize APScheduler for standalone worker
    scheduler = AsyncIOScheduler()
    
    # 1. Full Ingestion + Trending (Every 3 hours)
    scheduler.add_job(
        run_ingestion_and_trending, 
        'interval', 
        minutes=180, 
        id='orchestrate_news_and_trends', 
        replace_existing=True
    )
    
    # 2. Standalone Trending Update (Every hour, to pick up view-based ranking changes)
    scheduler.add_job(
        update_trending_scores,
        'interval',
        minutes=60,
        args=[active_pool, db.redis_client],
        id='periodic_trends',
        replace_existing=True
    )
    
    # Run once immediately on startup
    scheduler.add_job(run_ingestion_and_trending, id='worker_startup_sync')
    
    scheduler.start()
    logger.info("Worker started: Sync+Trend (180m), Periodic Trend (60m).")

    try:
        # Keep the worker running
        while True:
            await asyncio.sleep(3600)
    except (KeyboardInterrupt, SystemExit):
        logger.info("Worker shutting down...")
    finally:
        scheduler.shutdown()
        await db.close_connections()

if __name__ == "__main__":
    asyncio.run(main())
