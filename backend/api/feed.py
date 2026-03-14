import logging
from fastapi import APIRouter, HTTPException, Depends, Query, Request, BackgroundTasks
from uuid import UUID
import asyncpg
from typing import Optional
import orjson
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
    published_at, created_at, categories, subcategory, is_paywalled, country_code, trend_score
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
    Uses Redis category-level caching for high performance.
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
        redis_client = getattr(request.app.state, "redis_client", None)
        
        categories_to_fetch = []
        viewed_ids = set()
        
        async with db_pool.acquire() as conn:
            # 1. Determine categories
            if category:
                categories_to_fetch.append(category)
            elif user_id:
                try:
                    interest_records = await conn.fetch(
                        "SELECT category FROM user_interests WHERE user_id = $1", 
                        user_id
                    )
                    categories_to_fetch = [r['category'] for r in interest_records]
                except Exception as e:
                    logger.warning("Failed to fetch user interests: %s", e)
            
            if not categories_to_fetch:
                categories_to_fetch.append("all")
            
            # Normalize categories (lowercase and trimmed) to match Redis keys and DB storage
            categories_to_fetch = [str(c).strip().lower() for c in categories_to_fetch]
                
            # 2. Fetch viewed articles for user
            if user_id:
                try:
                    # Fetching all views is fast since it's an indexed UUID key,
                    # but if it grows too large, a limit could be applied here.
                    view_records = await conn.fetch(
                        "SELECT article_id FROM article_views WHERE user_id = $1::uuid", 
                        user_id
                    )
                    viewed_ids = {str(r['article_id']) for r in view_records}
                except Exception as e:
                    logger.warning("Failed to fetch viewed articles: %s", e)

            # 3. Fetch from Redis
            country_key = country or 'all'
            articles_by_cat = {}
            missing_categories = []
            
            if redis_client:
                import asyncio
                # Use normalized lowercase keys
                keys = [f"feed:v2:{country_key}:{cat}" for cat in categories_to_fetch]
                try:
                    cached_results = await asyncio.gather(*[redis_client.get(k) for k in keys])
                    for cat, cached in zip(categories_to_fetch, cached_results):
                        if cached:
                            try:
                                articles_by_cat[cat] = orjson.loads(cached)
                            except Exception as e:
                                logger.warning("Failed to parse cached JSON for %s: %s", cat, e)
                                missing_categories.append(cat)
                        else:
                            missing_categories.append(cat)
                except Exception as e:
                    logger.warning("Redis fetch error: %s", e)
                    missing_categories = categories_to_fetch.copy()
            else:
                missing_categories = categories_to_fetch.copy()
            
            # 4. Fallback to DB for missing categories (BATCH FETCH)
            all_articles = []
            # Add cached ones first
            for cat in categories_to_fetch:
                if cat in articles_by_cat:
                    all_articles.extend(articles_by_cat[cat])
            
            if missing_categories:
                # Filter out 'all' from categories list for SQL matching; 'all' is handled separately
                named_categories = [c for c in missing_categories if c != "all"]
                
                # Fetch naming categories in one go if any
                if named_categories or "all" in missing_categories:
                    where_clauses = []
                    params = []
                    
                    if "all" not in missing_categories:
                        # Only specific categories
                        where_clauses.append("categories && $1::text[]")
                        params.append(named_categories)
                        if country_key != 'all':
                            # Optionally filter by country if provided, but usually global feeds
                            # are what fill these categories. 
                            pass 
                    
                    where_sql = " WHERE " + " AND ".join(where_clauses) if where_clauses else ""
                    
                    # Increased limit slightly since we are fetching multiple categories in one go
                    # Ranking score: (1 + trend_score) * exp(-decay * hours_old)
                    # We use a decay of 0.05 per hour.
                    batch_query = f"""
                        SELECT {ARTICLE_COLUMNS},
                        ((1.0 + trend_score) * exp(-0.05 * extract(epoch from (now() - published_at))/3600)) as ranking_score
                        FROM articles
                        {where_sql}
                        ORDER BY ranking_score DESC
                        LIMIT 500
                    """
                    records = await conn.fetch(batch_query, *params)
                    
                    # Group records by category to store back in Redis
                    temp_results = {cat: [] for cat in missing_categories}
                    
                    for record in records:
                        r = dict(record)
                        r['published_at'] = r['published_at'].isoformat() if r.get('published_at') else None
                        r['created_at'] = r['created_at'].isoformat() if r.get('created_at') else None
                        r['id'] = str(r['id']) if r.get('id') else None
                        
                        # Add to overall results
                        r['ranking_score'] = record.get('ranking_score', 0.0)
                        all_articles.append(r)
                        
                        # Add to individual category buckets for Redis storage
                        # An article can be in multiple categories
                        if "all" in missing_categories:
                            temp_results["all"].append(r)
                            
                        article_cats = r.get('categories', [])
                        for cat in named_categories:
                            if cat in article_cats:
                                if len(temp_results[cat]) < 200: # Keep Redis caches lean
                                    temp_results[cat].append(r)

                    # Store back in Redis
                    if redis_client:
                        for cat, cat_articles in temp_results.items():
                            if cat_articles:
                                try:
                                    await redis_client.set(f"feed:v2:{country_key}:{cat}", orjson.dumps(cat_articles), ex=10800)
                                except Exception as e:
                                    logger.warning("Redis cache write error for %s: %s", cat, e)

        # 5. Deduplicate, filter viewed, filter before, sort
        seen = set()
        unique_filtered = []
        for a in all_articles:
            aid = a['id']
            if aid in seen:
                continue
            if aid in viewed_ids:
                continue
            if before and a.get('published_at'):
                # String comparison works for ISO-8601 timestamps
                if a['published_at'] >= before:
                    continue
            
            seen.add(aid)
            unique_filtered.append(a)
            
        # For 'For You' (all categories or personalized), sort by ranking score.
        # For specific categories, we still want to benefit from the trend boost.
        unique_filtered.sort(key=lambda x: x.get('ranking_score', 0.0), reverse=True)
        
        # 6. Apply pagination
        final_result = unique_filtered[offset:offset+limit]

        # 7. Metrics Logging (Observability)
        logger.info(
            f"Feed request: categories={len(categories_to_fetch)} "
            f"redis_hits={len(articles_by_cat)} "
            f"merged={len(all_articles)} "
            f"filtered_out={len(all_articles) - len(unique_filtered)} "
            f"returned={len(final_result)}"
        )
        
        return final_result

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

@router.post("/favorite")
@limiter.limit("60/minute")
async def toggle_favorite(
    request: Request,
    article_id: UUID,
    db_pool: asyncpg.Pool = Depends(get_db),
    user: User = Depends(verify_supabase_jwt)
):
    """
    Toggles the favorite status of an article for the user.
    If it exists, delete it; if not, insert it.
    """
    if not user:
        raise HTTPException(status_code=401, detail="Authentication required")
    try:
        async with db_pool.acquire() as conn:
            # We use a single query with a CTE or just check and swap.
            # Simplified: check if exists, then delete or insert.
            exists = await conn.fetchval(
                "SELECT 1 FROM article_favorites WHERE user_id = $1 AND article_id = $2",
                user.id, str(article_id)
            )
            
            if exists:
                await conn.execute(
                    "DELETE FROM article_favorites WHERE user_id = $1 AND article_id = $2",
                    user.id, str(article_id)
                )
                return {"status": "unfavorited"}
            else:
                await conn.execute(
                    "INSERT INTO article_favorites (user_id, article_id) VALUES ($1, $2)",
                    user.id, str(article_id)
                )
                return {"status": "favorited"}
    except HTTPException:
        raise
    except Exception as e:
        logger.error("Error toggling favorite: %s", e)
        raise HTTPException(status_code=500, detail="Failed to toggle favorite")
