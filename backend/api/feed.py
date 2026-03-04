from fastapi import APIRouter, HTTPException, Depends, Query, Request
import asyncpg
from typing import Optional, List
from ..core.security import limiter, verify_supabase_jwt, User

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
    db_pool: asyncpg.Pool = Depends(get_db),
    user: Optional[User] = Depends(verify_supabase_jwt) # Extract user if JWT present
):
    """
    Returns the newest articles, skipping ones the user has already viewed.
    """
    try:
        user_id = user.id if user else None
        
        async with db_pool.acquire() as conn:
            # Base WHERE clause
            where_clauses = []
            params = []
            
            if category:
                # categories on supabase schema is TEXT[] not JSONB
                where_clauses.append(f"$1 = ANY(categories)")
                params.append(category)
            
            if user_id:
                # Skip articles the user has already viewed
                # offset + 1 is the next parameter index
                p_idx = len(params) + 1
                where_clauses.append(f"id NOT IN (SELECT article_id FROM article_views WHERE user_id = ${p_idx}::uuid)")
                params.append(user_id)
            
            where_sql = " WHERE " + " AND ".join(where_clauses) if where_clauses else ""
            
            # Add limit/offset parameters
            l_idx = len(params) + 1
            o_idx = len(params) + 2
            params.extend([limit, offset])
            
            query = f"""
                SELECT * FROM articles
                {where_sql}
                ORDER BY published_at DESC
                LIMIT ${l_idx} OFFSET ${o_idx}
            """
            
            records = await conn.fetch(query, *params)
            return [dict(record) for record in records]
            
    except Exception as e:
        print(f"Database error in get_feed: {e}")
        raise HTTPException(status_code=500, detail="Failed to fetch articles")

@router.post("/view")
@limiter.limit("100/minute")
async def record_view(
    request: Request,
    article_id: str,
    db_pool: asyncpg.Pool = Depends(get_db),
    user: User = Depends(verify_supabase_jwt)
):
    """
    Records that a user has viewed an article.
    """
    try:
        async with db_pool.acquire() as conn:
            await conn.execute(
                "INSERT INTO article_views (user_id, article_id) VALUES ($1, $2) ON CONFLICT DO NOTHING",
                user.id, article_id
            )
            return {"status": "recorded"}
    except Exception as e:
        print(f"Error recording view: {e}")
        raise HTTPException(status_code=500, detail="Failed to record view")
