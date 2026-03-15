import logging
from fastapi import APIRouter, HTTPException, Depends, Query, Request, BackgroundTasks
import asyncpg
from typing import List, Optional
from ..core.security import limiter, verify_admin_api_key
from .feed import ARTICLE_COLUMNS, get_db
from ..services.trending import update_trending_scores

logger = logging.getLogger(__name__)

router = APIRouter()

@router.get("")
@limiter.limit("60/minute")
async def get_trending_feed(
    request: Request,
    limit: int = Query(20, ge=1, le=50),
    db_pool: asyncpg.Pool = Depends(get_db)
):
    """
    Returns the top trending articles globally based on trend_score.
    Ignores user interests as per requirements.
    """
    try:
        async with db_pool.acquire() as conn:
            # We fetch articles with the highest trend_score.
            # We also consider published_at to keep it relatively fresh (last 72 hours)
            # but priority is trend_score.
            query = f"""
                SELECT {ARTICLE_COLUMNS}
                FROM articles
                WHERE trend_score > 0
                AND published_at > NOW() - INTERVAL '72 hours'
                ORDER BY trend_score DESC, published_at DESC
                LIMIT $1
            """
            records = await conn.fetch(query, limit)
            
            articles = []
            for record in records:
                r = dict(record)
                r['published_at'] = r['published_at'].isoformat() if r.get('published_at') else None
                r['created_at'] = r['created_at'].isoformat() if r.get('created_at') else None
                r['id'] = str(r['id']) if r.get('id') else None
                articles.append(r)
                
            return articles

    except Exception as e:
        logger.error("Database error in get_trending_feed: %s", e)
        raise HTTPException(status_code=500, detail="Failed to fetch trending articles")

@router.post("/trigger")
async def trigger_trending_update(
    background_tasks: BackgroundTasks,
    db_pool: asyncpg.Pool = Depends(get_db),
    admin_key: str = Depends(verify_admin_api_key)
):
    """
    Manually triggers the trending score update process.
    """
    try:
        background_tasks.add_task(update_trending_scores, db_pool)
        return {"status": "trending_update_started"}
    except Exception as e:
        logger.error("Error triggering trending update: %s", e)
        raise HTTPException(status_code=500, detail=str(e))
