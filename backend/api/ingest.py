from fastapi import APIRouter, HTTPException, Depends, BackgroundTasks, Request
from pydantic import BaseModel
from typing import Optional

from ..services.ingestion import orchestrate, add_source_feed_to_queue
from ..core.security import verify_admin_api_key, limiter

router = APIRouter()

class IngestRequest(BaseModel):
    feedUrl: str
    categoryHint: Optional[str] = None

# NOTE: In the Hybrid Architecture, these endpoints trigger scraping from the 
# current container's IP. To avoid IP blocks, use these manual triggers primarily 
# on your local instance rather than the GCP API instance.

@router.post("/trigger")
@limiter.limit("5/minute;100/day")
async def trigger_ingestion(
    request: Request,
    ingest_req: IngestRequest,
    background_tasks: BackgroundTasks,
    admin_key: str = Depends(verify_admin_api_key)
):
    """
    Adds a single feed to the ingestion queue and triggers worker.
    """
    try:
        if request.app.state.redis_client:
            import orjson
            payload = orjson.dumps({
                "task": "ingest_feed",
                "feed_url": ingest_req.feedUrl,
                "category_hint": ingest_req.categoryHint
            }).decode('utf-8')
            await request.app.state.redis_client.publish("worker_tasks", payload)
        else:
            # Instead of blocking on the entire LLM processing, we add it to schedule/queue
            background_tasks.add_task(add_source_feed_to_queue, ingest_req.feedUrl, ingest_req.categoryHint)
        return {"status": "queued", "feedUrl": ingest_req.feedUrl}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.post("/orchestrate")
@limiter.limit("3/minute;60/day")
async def trigger_orchestrator(
    request: Request,
    background_tasks: BackgroundTasks,
    admin_key: str = Depends(verify_admin_api_key)
):
    """
    Manually triggers the ingestion of all configured RSS feeds.
    """
    try:
        if request.app.state.redis_client:
            await request.app.state.redis_client.publish("worker_tasks", "trigger_ingestion")
        else:
            # Orchestrate function loads the complete registry and adds all sources
            background_tasks.add_task(orchestrate)
        return {"status": "orchestration_started"}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.post("/cancel")
@limiter.limit("10/minute;120/day")
async def trigger_cancel(
    request: Request,
    admin_key: str = Depends(verify_admin_api_key)
):
    """
    Stops any ongoing full orchestration.
    """
    if request.app.state.redis_client:
        await request.app.state.redis_client.publish("worker_tasks", "cancel_ingestion")
    else:
        from ..services.ingestion import cancel_ingestion
        cancel_ingestion()
    return {"status": "cancellation_signaled"}
