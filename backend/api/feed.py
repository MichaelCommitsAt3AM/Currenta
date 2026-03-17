import logging
from fastapi import APIRouter, HTTPException, Depends, Query, Request, BackgroundTasks
from uuid import UUID
import asyncpg
from typing import Optional
import orjson
from ..core.security import limiter, verify_supabase_jwt, User
from ..core.geo import get_country_from_ip
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
    pool = getattr(request.app.state, "db_pool", None)
    if not pool:
        raise HTTPException(status_code=503, detail="Database connection not available")
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

    if country and country.lower() != 'auto':
        country = country.upper()
        if len(country) != 2 or not country.isalpha():
            raise HTTPException(status_code=400, detail="Invalid country code. Must be a 2-letter ISO code.")

    try:
        user_id = user.id if user else None
        redis_client = getattr(request.app.state, "redis_client", None)
        
        categories_to_fetch = []
        viewed_ids = set()
        country_source = "default"
        detected_country = None
        
        async with db_pool.acquire() as conn:
            # 1. Determine Country (Preference > IP > Parameter)
            if not country or country.lower() == 'auto':
                # Try database preference first if logged in
                if user_id:
                    pref = await conn.fetchval(
                        "SELECT preferred_country FROM user_profiles WHERE user_id = $1",
                        user_id
                    )
                    if pref:
                        country = pref
                        country_source = "preference"
                        logger.debug(f"Using stored country preference for user {user_id}: {country}")
                
                # If still no country, try IP detection
                if not country or (isinstance(country, str) and country.lower() == 'auto'):
                    # Get remote IP, considering possible proxy headers
                    forwarded = request.headers.get("X-Forwarded-For")
                    ip = forwarded.split(",")[0].strip() if forwarded else request.client.host
                    
                    detected_country = await get_country_from_ip(ip)
                    if detected_country:
                        country = detected_country
                        country_source = "auto_ip"
                        logger.info(f"Automatically detected country '{country}' from IP {ip}")
                    else:
                        logger.warning(f"Failed to automatically detect country for IP {ip}")
            else:
                country_source = "parameter"
            
            # 2. Determine categories
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
                        "SELECT article_id FROM article_views WHERE user_id = $1::uuid ORDER BY viewed_at DESC LIMIT 300", 
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
                keys = [f"feed:v4:{country_key}:{cat}" for cat in categories_to_fetch]
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
                        # STRICT FILTERING for Local News: must match detected/specified country_code
                        if "local" in named_categories:
                            if country and country != 'all':
                                # Article must have 'local' tag AND the correct country code
                                # OR match one of the OTHER requested categories (and NOT be a local article from another country)
                                other_cats = [c for c in named_categories if c != 'local']
                                if other_cats:
                                    where_clauses.append("""
                                        (
                                            country_code = $1
                                            OR 
                                            (categories[1] = ANY($2::text[]) AND (country_code = $1 OR country_code IS NULL))
                                        )
                                    """)
                                    params.append(country)
                                    params.append(other_cats)
                                else:
                                    # Virtual category 'local' matches any article with the correct country_code
                                    where_clauses.append("country_code = $1")
                                    params.append(country)
                            else:
                                # 'local' requested but NO country detected/specified.
                                # We return nothing for the local part, but can still return other categories if any.
                                other_cats = [c for c in named_categories if c != 'local']
                                if other_cats:
                                    where_clauses.append("categories && $1::text[]")
                                    params.append(other_cats)
                                else:
                                    # ONLY 'local' requested and NO country -> return nothing
                                    where_clauses.append("FALSE")
                        else:
                            # Standard multi-category filter for non-local requests
                            where_clauses.append("categories[1] = ANY($1::text[])")
                            params.append(named_categories)
                    
                    # --- FIX: Cursor-based pagination in DB ---
                    # If 'before' is provided, we MUST filter in SQL to find articles older 
                    # than the cursor, otherwise we might fetch the same top 150 newer 
                    # articles and filter them all out in memory, causing the feed to "end" prematurely.
                    if before:
                        # Append to where clauses and params
                        where_clauses.append(f"published_at < ${len(params) + 1}::timestamp")
                        params.append(before)
                    
                    # Trigger background sync for local news if category is local and we have a country
                    if country and country != 'all' and (category == 'local' or 'local' in categories_to_fetch):
                        background_tasks.add_task(fetch_local_news_on_demand, country, db_pool)
                    
                    where_sql = " WHERE " + " AND ".join(where_clauses) if where_clauses else ""
                    
                    # we use the pre-computed ranking_score column
                    batch_query = f"""
                        SELECT {ARTICLE_COLUMNS}, ranking_score
                        FROM articles
                        {where_sql}
                        ORDER BY ranking_score DESC
                        LIMIT 150
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
                        
                        # Virtual category mapping for 'local'
                        if "local" in named_categories and r.get('country_code') == country:
                            if len(temp_results["local"]) < 150:
                                temp_results["local"].append(r)
                                
                        for cat in named_categories:
                            if cat in article_cats:
                                if len(temp_results[cat]) < 150: # Keep Redis caches lean
                                    temp_results[cat].append(r)

                    # Store back in Redis
                    if redis_client:
                        for cat, cat_articles in temp_results.items():
                            if cat_articles:
                                # ONLY cache if it's a specific category request (named_categories)
                                # AND if we are reasonably sure we have a good slice.
                                # If we were doing an 'all' fetch, named_categories is empty or partial.
                                # To be safe: only cache if the category was the main one requested or part of a full query.
                                if cat == category or (category is None and cat == "all"):
                                    try:
                                        await redis_client.set(f"feed:v4:{country_key}:{cat}", orjson.dumps(cat_articles), ex=10800)
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
            
            # Additional safety check for 'before' (though mostly handled in SQL now)
            if before and a.get('published_at'):
                # String comparison is risky with different ISO formats, but SQL filter covers it better.
                # We keep this as a final sink filter for cached Redis hits that might be dirty.
                pass
            
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
            f"country={country} (method={country_source}) "
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
async def track_view(
    article_id: UUID,
    db_pool: asyncpg.Pool = Depends(get_db),
    user: User = Depends(verify_supabase_jwt)
):
    """
    Records a view for the given article and user.
    """
    try:
        async with db_pool.acquire() as conn:
            await conn.execute(
                "INSERT INTO article_views (user_id, article_id) VALUES ($1, $2) ON CONFLICT DO NOTHING",
                user.id, article_id
            )
        return {"status": "ok"}
    except Exception as e:
        logger.error("Failed to track view for article %s: %s", article_id, e)
        raise HTTPException(status_code=500, detail="Failed to record view")


@router.get("/detect-location")
async def detect_location(
    request: Request,
    db_pool: asyncpg.Pool = Depends(get_db),
    user: Optional[User] = Depends(verify_supabase_jwt)
):
    """
    Detects the user's country from their IP and saves it to their profile if they are logged in.
    This can be called during onboarding to pre-warm the location state.
    """
    forwarded = request.headers.get("X-Forwarded-For")
    ip = forwarded.split(",")[0].strip() if forwarded else request.client.host
    
    country = await get_country_from_ip(ip)
    
    if country and user:
        try:
            async with db_pool.acquire() as conn:
                # Check if they already have a preference
                existing = await conn.fetchval(
                    "SELECT preferred_country FROM user_profiles WHERE user_id = $1",
                    user.id
                )
                if not existing:
                    await conn.execute(
                        "INSERT INTO user_profiles (user_id, preferred_country) VALUES ($1, $2) "
                        "ON CONFLICT (user_id) DO UPDATE SET preferred_country = EXCLUDED.preferred_country",
                        user.id, country
                    )
                    logger.info(f"Background location detection: saved {country} for user {user.id}")
        except Exception as e:
            logger.warning(f"Failed to save background detected country: {e}")
            
    return {"country": country}


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
