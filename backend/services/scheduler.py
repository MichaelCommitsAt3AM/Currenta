import logging
import math
from apscheduler.schedulers.asyncio import AsyncIOScheduler

logger = logging.getLogger(__name__)

scheduler = AsyncIOScheduler()

def start_scheduler():
    """
    Starts system-wide background jobs (Trending, View Flushing).
    In the split architecture, this runs within the API server (GCP).
    """
    from .ingestion import flush_view_buffer
    from .trending import update_trending_scores
    from ..core import db

    # 1. Trending updates (DB intensive)
    scheduler.add_job(
        update_trending_scores, 
        'interval', 
        minutes=60, 
        id='update_trends', 
        args=[db.db_pool], 
        replace_existing=True
    )
    
    # 2. View buffer flushing (Redis -> PG)
    scheduler.add_job(
        flush_view_buffer, 
        'interval', 
        seconds=60, 
        id='flush_views', 
        args=[db.db_pool, db.redis_client], 
        replace_existing=True
    )
    
    scheduler.start()
    logger.info("System scheduler started (Trends: 60m, View-Flush: 60s).")

def stop_scheduler():
    if scheduler.running:
        scheduler.shutdown(wait=False)
        logger.info("System scheduler stopped.")
