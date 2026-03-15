import logging
import math
from apscheduler.schedulers.asyncio import AsyncIOScheduler

logger = logging.getLogger(__name__)

scheduler = AsyncIOScheduler()

def start_scheduler():
    # Import locally to avoid circular dependencies
    from .ingestion import orchestrate_sync_wrapper
    from .trending import update_trending_scores
    
    # Run orchestration every ~3 hours like the Flutter Background Fetch used to
    scheduler.add_job(orchestrate_sync_wrapper, 'interval', minutes=180, id='orchestrate_news', replace_existing=True)
    
    # Run trending updates every 15 minutes
    from ..main import db_pool
    scheduler.add_job(update_trending_scores, 'interval', minutes=15, id='update_trends', args=[db_pool], replace_existing=True)

    scheduler.start()
    logger.info("Background scheduler started: orchestration (180m) and trends (15m).")

def stop_scheduler():
    scheduler.shutdown(wait=False)
