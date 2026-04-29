import logging
from datetime import datetime, timedelta
from .scheduler import scheduler
from ..core import db
from uuid import UUID

logger = logging.getLogger(__name__)

async def update_user_profile_vector_task(user_id: UUID):
    """
    Background task to execute the SQL interest vector recalculation.
    """
    logger.info(f"Executing interest vector update for user: {user_id}")
    try:
        if not db.db_pool:
            logger.error("DB Pool not available for personalization task")
            return
            
        async with db.db_pool.acquire() as conn:
            # We call the SQL function we just fixed
            await conn.execute("SELECT update_user_interest_vector($1)", user_id)
            logger.info(f"Successfully updated interest vector for user: {user_id}")
    except Exception as e:
        logger.error(f"Failed to update interest vector for user {user_id}: {e}")

def schedule_debounced_personalization_update(user_id: str):
    """
    Schedules a profile update 30 seconds into the future.
    If a task already exists for this user, it is replaced (debounced).
    """
    try:
        # Convert to UUID object for the task but use string for job ID
        uid_obj = UUID(user_id)
        job_id = f"update_interests_{user_id}"
        
        run_at = datetime.now() + timedelta(seconds=30)
        
        # add_job with replace_existing=True and a fixed ID handles the debouncing
        scheduler.add_job(
            update_user_profile_vector_task,
            'date',
            run_date=run_at,
            args=[uid_obj],
            id=job_id,
            replace_existing=True,
            misfire_grace_time=10 # If the scheduler is busy, give it some slack
        )
        logger.info(f"Scheduled debounced personalization update for user {user_id} in 30s")
    except Exception as e:
        logger.error(f"Error scheduling personalization update for user {user_id}: {e}")
