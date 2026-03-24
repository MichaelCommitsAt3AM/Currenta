import logging
import math
from apscheduler.schedulers.asyncio import AsyncIOScheduler

logger = logging.getLogger(__name__)

scheduler = AsyncIOScheduler()

def start_scheduler():
    # Import locally to avoid circular dependencies
    from .ingestion import orchestrate_sync_wrapper
    from .trending import update_trending_scores
    
    # Run orchestration every ~3 hours
    scheduler.add_job(orchestrate_sync_wrapper, 'interval', minutes=180, id='orchestrate_news', replace_existing=True)
    
    # Run trending updates every 12 hours (Audit Recommendation)
    from ..main import db_pool, redis_client
    scheduler.add_job(update_trending_scores, 'interval', hours=12, id='update_trends', args=[db_pool], replace_existing=True)

    # Flush view buffer every 60 seconds (Audit Recommendation)
    from .ingestion import flush_view_buffer
    scheduler.add_job(flush_view_buffer, 'interval', seconds=60, id='flush_views', args=[db_pool, redis_client], replace_existing=True)

    scheduler.start()
    logger.info("Background scheduler started: orchestration (180m), trends (12h), view-flush (60s).")

def stop_scheduler():
    scheduler.shutdown(wait=False)
