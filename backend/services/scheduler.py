import math
from apscheduler.schedulers.asyncio import AsyncIOScheduler
# Using BackgroundScheduler wouldn't work easily with asyncpg connections
# we will use AsyncIOScheduler and run it in the main event loop

scheduler = AsyncIOScheduler()

def start_scheduler():
    # Import locally to avoid circular dependencies
    from .ingestion import orchestrate_sync_wrapper
    
    # Run orchestration every ~3 hours like the Flutter Background Fetch used to
    scheduler.add_job(orchestrate_sync_wrapper, 'interval', minutes=180, id='orchestrate_news', replace_existing=True)
    scheduler.start()
    print("Background scheduler started: Next orchestration job in 180 minutes.")

def stop_scheduler():
    scheduler.shutdown(wait=False)
