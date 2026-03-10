import logging
from fastapi import APIRouter, HTTPException, Depends, Query, Request, BackgroundTasks
from uuid import UUID
import asyncpg
from typing import Optional
from ..core.security import limiter, verify_supabase_jwt, User
from ..services.ingestion import fetch_local_news_on_demand

logger = logging.getLogger(__name__)

router = APIRouter()

# Allowlist of valid category values — validated before any SQL is built
VALID_CATEGORIES = frozenset([
    "politics", "tech", "science", "business", "sports",
    "entertainment", "health", "world", "local", "environment"
])

# Only these columns are sent to the client — never the embedding vector or internal fields
ARTICLE_COLUMNS = """
    id, title, summary, original_url, image_url, source_name,
    published_at, created_at, categories, subcategory, is_paywalled, country_code
"""

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
    country: Optional[str] = Query(None, description="Country code for local news (e.g. KE, US)"),
    limit: int = Query(30, ge=1, le=100, description="Number of items to return"),
    offset: int = Query(0, ge=0, description="Pagination offset"),
    before: Optional[str] = Query(None, description="Only return articles published before this ISO timestamp (cursor)"),
    background_tasks: BackgroundTasks = BackgroundTasks(),
    db_pool: asyncpg.Pool = Depends(get_db),
    user: Optional[User] = Depends(verify_supabase_jwt)
):
    """
    Returns the newest articles, skipping ones the user has already viewed.
    Supports cursor-based pagination via 'before' parameter.
    """
    # --- Input validation ---
    if category and category not in VALID_CATEGORIES:
        raise HTTPException(status_code=400, detail=f"Invalid category '{category}'.")

    if country:
        country = country.upper()
        if len(country) != 2 or not country.isalpha():
            raise HTTPException(status_code=400, detail="Invalid country code. Must be a 2-letter ISO code.")

    try:
        user_id = user.id if user else None

        async with db_pool.acquire() as conn:
            where_clauses = []
            params = []

            if category:
                if category == "local" and country:
                    where_clauses.append(f"$1 = ANY(categories) AND country_code = $2")
                    params.extend([category, country])
                else:
                    where_clauses.append(f"$1 = ANY(categories)")
                    params.append(category)

            if before:
                p_idx = len(params) + 1
                where_clauses.append(f"published_at < ${p_idx}")
                params.append(before)

            if user_id:
                p_idx = len(params) + 1
                where_clauses.append(f"id NOT IN (SELECT article_id FROM article_views WHERE user_id = ${p_idx}::uuid)")
                params.append(user_id)

            where_sql = " WHERE " + " AND ".join(where_clauses) if where_clauses else ""

            l_idx = len(params) + 1
            o_idx = len(params) + 2
            params.extend([limit, offset])

            query = f"""
                SELECT {ARTICLE_COLUMNS}
                FROM articles
                {where_sql}
                ORDER BY published_at DESC
                LIMIT ${l_idx} OFFSET ${o_idx}
            """

            records = await conn.fetch(query, *params)
            return [dict(record) for record in records]

    except HTTPException:
        raise
    except Exception as e:
        logger.error("Database error in get_feed: %s", e)
        raise HTTPException(status_code=500, detail="Failed to fetch articles")

@router.post("/view")
@limiter.limit("100/minute")
async def record_view(
    request: Request,
    article_id: UUID,
    db_pool: asyncpg.Pool = Depends(get_db),
    user: User = Depends(verify_supabase_jwt)
):
    """
    Records that a user has viewed an article.
    """
    if not user:
        raise HTTPException(status_code=401, detail="Authentication required")
    try:
        async with db_pool.acquire() as conn:
            await conn.execute(
                "INSERT INTO article_views (user_id, article_id) VALUES ($1, $2) ON CONFLICT DO NOTHING",
                user.id, str(article_id)
            )
            return {"status": "recorded"}
    except HTTPException:
        raise
    except Exception as e:
        logger.error("Error recording view: %s", e)
        raise HTTPException(status_code=500, detail="Failed to record view")
