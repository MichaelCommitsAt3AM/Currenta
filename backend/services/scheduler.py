import logging
import math
from apscheduler.schedulers.asyncio import AsyncIOScheduler

logger = logging.getLogger(__name__)

scheduler = AsyncIOScheduler()

def start_scheduler():
    # Import locally to avoid circular dependencies
    from .ingestion import orchestrate_sync_wrapper
    
    # Run orchestration every ~3 hours like the Flutter Background Fetch used to
    scheduler.add_job(orchestrate_sync_wrapper, 'interval', minutes=180, id='orchestrate_news', replace_existing=True)
    scheduler.start()
    logger.info("Background scheduler started: next orchestration job in 180 minutes.")

def stop_scheduler():
    scheduler.shutdown(wait=False)
