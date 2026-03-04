from fastapi import APIRouter, HTTPException, Depends, Query, Request
import asyncpg
from typing import Optional, List
from ..core.security import limiter

router = APIRouter()

def get_db(request: Request) -> asyncpg.Pool:
    pool = request.app.state.db_pool
    if not pool:
        raise HTTPException(status_code=500, detail="Database connection not available")
    return pool

@router.get("")
@limiter.limit("60/minute")
async def get_feed(
    request: Request,
    category: Optional[str] = Query(None, description="Filter articles by category"),
    limit: int = Query(30, ge=1, le=100, description="Number of items to return"),
    offset: int = Query(0, ge=0, description="Pagination offset"),
    db_pool: asyncpg.Pool = Depends(get_db)
):
    """
    Returns the newest articles from the Supabase Postgres database.
    """
    try:
        async with db_pool.acquire() as conn:
            if category:
                # Use array containment operator for the JSONB 'categories' array
                # Supabase schema uses JSONB for 'categories'
                query = """
                    SELECT * FROM articles
                    WHERE categories @> $1::jsonb
                    ORDER BY published_at DESC
                    LIMIT $2 OFFSET $3
                """
                # postgres json literal parameter for string array
                jsonb_param = f'["{category}"]'
                records = await conn.fetch(query, jsonb_param, limit, offset)
            else:
                query = """
                    SELECT * FROM articles
                    ORDER BY published_at DESC
                    LIMIT $1 OFFSET $2
                """
                records = await conn.fetch(query, limit, offset)
            
            # Convert asyncpg Record objects to dict
            return [dict(record) for record in records]
            
    except Exception as e:
        print(f"Database error in get_feed: {e}")
        raise HTTPException(status_code=500, detail="Failed to fetch articles")
