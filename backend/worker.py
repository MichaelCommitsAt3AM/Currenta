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

async def listen_for_tasks():
    """Listens for manual triggers from the API server on Redis pub/sub."""
    logger.info("Worker: Listening for manual task triggers on Redis channel 'worker_tasks'...")
    pubsub = db.redis_client.pubsub()
    await pubsub.subscribe("worker_tasks")
    try:
        while True:
            message = await pubsub.get_message(ignore_subscribe_messages=True, timeout=2.0)
            if message:
                payload = message["data"]
                logger.info(f"Worker: Received task trigger payload: {payload}")
                try:
                    if payload == "trigger_trending":
                        logger.info("Worker: Starting manual trending score update...")
                        asyncio.create_task(update_trending_scores(db.db_pool, db.redis_client))
                    elif payload == "trigger_ingestion":
                        logger.info("Worker: Starting manual news ingestion orchestrator...")
                        from .services.ingestion import orchestrate
                        asyncio.create_task(orchestrate())
                    elif payload == "cancel_ingestion":
                        logger.info("Worker: Cancelling ongoing ingestion...")
                        from .services.ingestion import cancel_ingestion
                        cancel_ingestion()
                    else:
                        # Single feed ingestion JSON payload
                        import orjson
                        data = orjson.loads(payload)
                        task_type = data.get("task")
                        if task_type == "ingest_feed":
                            feed_url = data.get("feed_url")
                            category_hint = data.get("category_hint")
                            logger.info(f"Worker: Starting manual single-feed ingestion: {feed_url} ({category_hint})")
                            from .services.ingestion import add_source_feed_to_queue
                            asyncio.create_task(add_source_feed_to_queue(feed_url, category_hint))
                except Exception as e:
                    logger.error(f"Worker: Error processing task payload: {e}", exc_info=True)
            await asyncio.sleep(0.5)
    except asyncio.CancelledError:
        logger.info("Worker: Task listener stopped.")
    except Exception as e:
        logger.error(f"Worker: Task listener encountered error: {e}", exc_info=True)

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
    
    # 2. Periodic Trending Updates (Every 60 minutes)
    scheduler.add_job(
        update_trending_scores,
        'interval',
        minutes=60,
        id='periodic_trending_update',
        args=[db.db_pool, db.redis_client],
        replace_existing=True
    )
    
    # Run once immediately on startup
    scheduler.add_job(run_ingestion_and_trending, id='worker_startup_sync')
    
    scheduler.start()
    logger.info("Worker started: Sync+Trend (180m), Periodic Trend (60m).")

    # Start Redis Pub/Sub listener for manual task triggers
    listener_task = asyncio.create_task(listen_for_tasks())

    try:
        # Keep the worker running
        while True:
            await asyncio.sleep(3600)
    except (KeyboardInterrupt, SystemExit):
        logger.info("Worker shutting down...")
    finally:
        listener_task.cancel()
        try:
            await listener_task
        except asyncio.CancelledError:
            pass
        scheduler.shutdown()
        await db.close_connections()

if __name__ == "__main__":
    asyncio.run(main())
