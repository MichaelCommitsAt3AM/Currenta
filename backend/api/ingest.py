from fastapi import APIRouter, HTTPException, Depends, BackgroundTasks
from pydantic import BaseModel
from typing import Optional

from ..services.ingestion import orchestrate, add_source_feed_to_queue
from ..core.security import verify_admin_api_key

router = APIRouter()

class IngestRequest(BaseModel):
    feedUrl: str
    categoryHint: Optional[str] = None

@router.post("/trigger")
async def trigger_ingestion(
    request: IngestRequest, 
    background_tasks: BackgroundTasks,
    admin_key: str = Depends(verify_admin_api_key)
):
    """
    Adds a single feed to the ingestion queue and triggers worker.
    """
    try:
        # Instead of blocking on the entire LLM processing, we add it to schedule/queue
        background_tasks.add_task(add_source_feed_to_queue, request.feedUrl, request.categoryHint)
        return {"status": "queued", "feedUrl": request.feedUrl}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.post("/orchestrate")
async def trigger_orchestrator(
    background_tasks: BackgroundTasks,
    admin_key: str = Depends(verify_admin_api_key)
):
    """
    Manually triggers the ingestion of all configured RSS feeds.
    """
    try:
        # Orchestrate function loads the complete registry and adds all sources
        background_tasks.add_task(orchestrate)
        return {"status": "orchestration_started"}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
