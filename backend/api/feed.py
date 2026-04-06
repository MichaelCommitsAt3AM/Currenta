import logging
import asyncio
import re
from datetime import datetime
from urllib.parse import urlparse
from fastapi import APIRouter, HTTPException, Depends, Query, Request, BackgroundTasks
from uuid import UUID
import asyncpg
from typing import Optional, List, Dict, Set
import orjson
from ..core.security import limiter, verify_supabase_jwt, User, get_client_ip
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
    published_at, created_at, categories, subcategory, is_paywalled, country_code, trend_score, cluster_id
"""

_WORD_RE = re.compile(r"[a-z0-9]+")
_TEXT_STOPWORDS = {
    "a", "an", "the", "and", "or", "but", "for", "of", "on", "in", "to", "with",
    "from", "by", "at", "as", "after", "before", "amid", "into", "over", "under",
    "about", "says", "say", "new", "update", "latest", "report", "reports", "this",
    "that", "their", "they", "them", "while", "could", "would", "into", "than", "then"
}
_MIN_TOKEN_LEN = 3
_NEAR_DUP_MIN_SHARED_TOKENS = 4
_NEAR_DUP_JACCARD_THRESHOLD = 0.30
_TOKEN_NORMALIZATION_MAP = {
    "misled": "mislead",
    "misleading": "mislead",
    "investor": "invest",
    "investors": "invest",
    "lawsuit": "legal",
    "jury": "legal",
    "damages": "damage",
    "acquisition": "acquire",
    "acquired": "acquire",
    "acquiring": "acquire",
}


def _normalize_token(token: str) -> str:
    if token in _TOKEN_NORMALIZATION_MAP:
        return _TOKEN_NORMALIZATION_MAP[token]
    # Very light stemming to align small wording changes across sources.
    if len(token) > 6 and token.endswith("ing"):
        token = token[:-3]
    elif len(token) > 5 and token.endswith("ed"):
        token = token[:-2]
    elif len(token) > 5 and token.endswith("es"):
        token = token[:-2]
    elif len(token) > 4 and token.endswith("s"):
        token = token[:-1]
    return token


def _extract_url_slug(url: Optional[str]) -> str:
    if not url:
        return ""
    try:
        path = urlparse(url).path or ""
        return path.replace("-", " ").replace("_", " ").replace("/", " ")
    except Exception:
        return ""


def _article_tokens(article: dict) -> Set[str]:
    parts = [
        article.get("title") or "",
        article.get("summary") or "",
        _extract_url_slug(article.get("original_url")),
    ]
    raw_tokens = _WORD_RE.findall(" ".join(parts).lower())
    cleaned = set()
    for token in raw_tokens:
        if len(token) < _MIN_TOKEN_LEN or token in _TEXT_STOPWORDS:
            continue
        cleaned.add(_normalize_token(token))
    return cleaned


def _token_jaccard_similarity(tokens_a: Set[str], tokens_b: Set[str]) -> float:
    if not tokens_a or not tokens_b:
        return 0.0
    union = tokens_a | tokens_b
    if not union:
        return 0.0
    return len(tokens_a & tokens_b) / len(union)


def _collapse_near_duplicate_articles(articles: List[dict]) -> List[dict]:
    """
    Keeps higher-ranked articles and suppresses near-duplicate headlines
    from other sources in the same feed response.
    Updated: removed subcategory grouping to ensure stories are deduplicated globally.
    O(N^2) for N=150 is negligible (< 10ms).
    """
    kept: List[dict] = []
    # List of token sets for articles we decided to keep
    kept_token_sets: List[Set[str]] = []

    for article in articles:
        candidate_tokens = _article_tokens(article)
        is_near_duplicate = False
        
        # We compare against all already-kept articles to ensure global uniqueness.
        for existing_tokens in kept_token_sets:
            # Quick overlap check to avoid full Jaccard calculation
            if len(candidate_tokens & existing_tokens) < _NEAR_DUP_MIN_SHARED_TOKENS:
                continue
                
            similarity = _token_jaccard_similarity(candidate_tokens, existing_tokens)
            if similarity >= _NEAR_DUP_JACCARD_THRESHOLD:
                is_near_duplicate = True
                break

        if not is_near_duplicate:
            kept.append(article)
            kept_token_sets.append(candidate_tokens)

    return kept


def _parse_iso_datetime(value: Optional[str]) -> Optional[datetime]:
    if not value:
        return None
    try:
        return datetime.fromisoformat(value.replace("Z", "+00:00"))
    except Exception:
        return None


def get_db(request: Request) -> asyncpg.Pool:
    pool = getattr(request.app.state, "db_pool", None)
    if not pool:
        raise HTTPException(status_code=503, detail="Database connection not available")
    return pool


async def get_user_state(user_id: str, db_pool: asyncpg.Pool, redis_client) -> dict:
    """Fetch user country preference + interests, with Redis caching (Recommendation 2.1)."""
    cache_key = f"user_state:{user_id}"
    if redis_client:
        try:
            cached = await redis_client.get(cache_key)
            if cached:
                return orjson.loads(cached)
        except Exception as e:
            logger.warning("Redis user_state cache hit error: %s", e)

    # Cache miss — hit DB with parallel queries
    async with db_pool.acquire() as conn:
        pref = await conn.fetchval(
            "SELECT preferred_country FROM user_profiles WHERE user_id = $1", user_id
        )
        interest_records = await conn.fetch(
            "SELECT category FROM user_interests WHERE user_id = $1", user_id
        )

    state = {
        "preferred_country": pref,
        "interests": [r["category"] for r in interest_records],
    }

    if redis_client:
        try:
            await redis_client.set(cache_key, orjson.dumps(state), ex=300) # 5 min TTL
        except Exception as e:
            logger.warning("Redis user_state cache set error: %s", e)

    return state


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
        ip = get_client_ip(request)
        
        country_source = "default"
        detected_country = None
        user_state = None
        
        # 1. Parallelize Geo-IP Detection and User State Fetch (Recommendation 2.3)
        geo_task = get_country_from_ip(ip) if (not country or country.lower() == 'auto') else asyncio.sleep(0)
        state_task = get_user_state(str(user_id), db_pool, redis_client) if user_id else asyncio.sleep(0)
        
        gathered = await asyncio.gather(geo_task, state_task)
        detected_country = gathered[0] if isinstance(gathered[0], str) else None
        user_state = gathered[1] if isinstance(gathered[1], dict) else None
        
        # 2. Determine Country & Categories
        if not country or country.lower() == 'auto':
            if user_state and user_state.get("preferred_country"):
                country = user_state["preferred_country"]
                country_source = "preference"
            elif detected_country:
                country = detected_country
                country_source = "auto_ip"
            else:
                country = None
        else:
            country_source = "parameter"

        categories_to_fetch = []
        if category:
            categories_to_fetch.append(category)
        elif user_state and user_state.get("interests"):
            categories_to_fetch = list(user_state["interests"])
        
        if not categories_to_fetch:
            categories_to_fetch.append("all")
        
        # Normalize categories
        categories_to_fetch = [str(c).strip().lower() for c in categories_to_fetch]
            
        # 3. Fetch from Redis
        country_key = country or 'all'
        articles_by_cat = {}
        missing_categories = []
        required_cached_count = max(limit + offset, 10)
        before_dt = _parse_iso_datetime(before) if before else None
        
        if redis_client:
            keys = [f"feed:v4:{country_key}:{cat}" for cat in categories_to_fetch]
            try:
                cached_results = await asyncio.gather(*[redis_client.get(k) for k in keys])
                for cat, cached in zip(categories_to_fetch, cached_results):
                    if cached:
                        try:
                            cat_articles = orjson.loads(cached)
                            if before_dt:
                                cat_articles = [
                                    a for a in cat_articles
                                    if (
                                        (parsed := _parse_iso_datetime(a.get("published_at")))
                                        and parsed < before_dt
                                    )
                                ]
                            articles_by_cat[cat] = cat_articles
                            # Treat sparse cache as a partial miss and top up from DB.
                            if len(cat_articles) < required_cached_count:
                                missing_categories.append(cat)
                        except Exception as e:
                            logger.warning("Failed to parse cached JSON for %s: %s", cat, e)
                            missing_categories.append(cat)
                    else:
                        missing_categories.append(cat)
            except Exception as e:
                logger.warning("Redis fetch error: %s", e)
                missing_categories = list(categories_to_fetch)
        else:
            missing_categories = list(categories_to_fetch)
        
        # 4. Fallback to DB for missing categories
        all_articles = []
        # Add cached ones first
        for cat in categories_to_fetch:
            if cat in articles_by_cat:
                all_articles.extend(articles_by_cat[cat])
        
        if missing_categories:
            named_categories = [c for c in missing_categories if c != "all"]
            if named_categories or "all" in missing_categories:
                where_clauses = []
                params = []
                
                # We always want country as $1 for the ORDER BY boost if it exists
                # This ensures consistent parameter indexing.
                params.append(country if (country and country != 'all') else None)
                
                cat_params_idx = None
                if "all" not in missing_categories:
                    cat_params_idx = len(params) + 1
                    params.append(named_categories)
                    
                    if "local" in named_categories:
                        if country and country != 'all':
                            # For the 'local' category specifically, we are still strict.
                            # For other categories, we allow anything but prioritize $1.
                            where_clauses.append(f"""
                                (
                                    (categories && ARRAY['local']::text[] AND country_code = $1)
                                    OR 
                                    (categories && ${cat_params_idx}::text[] AND (country_code = $1 OR country_code IS NULL OR country_code != $1))
                                )
                            """)
                        else:
                            where_clauses.append(f"categories && ${cat_params_idx}::text[]")
                    else:
                        # General categories: allow all country codes, sorting handles priority
                        where_clauses.append(f"categories && ${cat_params_idx}::text[]")
                
                if before:
                    where_clauses.append(f"published_at < ${len(params) + 1}::timestamp")
                    params.append(before)
                
                # Push viewed filtering into the DB subquery
                if user_id:
                    where_clauses.append(f"""
                        id NOT IN (
                            SELECT article_id FROM article_views
                            WHERE user_id = ${len(params) + 1}::uuid
                            ORDER BY viewed_at DESC
                            LIMIT 300
                        )
                    """)
                    params.append(user_id)
                
                # Background sync for local news
                if country and country != 'all' and (category == 'local' or 'local' in categories_to_fetch):
                    background_tasks.add_task(fetch_local_news_on_demand, country, db_pool)
                
                where_sql = " WHERE " + " AND ".join(where_clauses) if where_clauses else ""
                
                # Sort Priority:
                # 1. Matching country code (if set)
                # 2. Main category match (if requested)
                # 3. Tier 1: Trending (trend_score > 0)
                # 4. Tier 2: Major News (is_major_source = TRUE)
                # 5. Tier 3: Others / Ranking score (score as tie-breaker)
                country_boost = "CASE WHEN $1::text IS NOT NULL AND country_code = $1 THEN 0 ELSE 1 END"
                category_priority = f"CASE WHEN categories[1] = ANY(${cat_params_idx}::text[]) THEN 0 ELSE 1 END" if cat_params_idx else "0"
                trending_tier = "CASE WHEN trend_score > 0 THEN 0 ELSE 1 END"
                major_source_tier = "CASE WHEN is_major_source = TRUE THEN 0 ELSE 1 END"

                batch_query = f"""
                    SELECT {ARTICLE_COLUMNS}, ranking_score
                    FROM articles
                    {where_sql}
                    ORDER BY {country_boost} ASC, {category_priority} ASC, {trending_tier} ASC, {major_source_tier} ASC, ranking_score DESC
                    LIMIT 300
                """
                async with db_pool.acquire() as conn:
                    records = await conn.fetch(batch_query, *params)
                logger.info(
                    "Feed DB fallback: country=%s categories=%s missing=%s required_cached_count=%s db_rows=%s",
                    country,
                    categories_to_fetch,
                    missing_categories,
                    required_cached_count,
                    len(records),
                )
                
                temp_results = {cat: [] for cat in missing_categories}
                for record in records:
                    r = dict(record)
                    r['published_at'] = r['published_at'].isoformat() if r.get('published_at') else None
                    r['created_at'] = r['created_at'].isoformat() if r.get('created_at') else None
                    r['id'] = str(r['id']) if r.get('id') else None
                    r['cluster_id'] = str(r['cluster_id']) if r.get('cluster_id') else None
                    r['ranking_score'] = record.get('ranking_score', 0.0)
                    all_articles.append(r)
                    
                    if "all" in missing_categories:
                        temp_results["all"].append(r)
                        
                    article_cats = r.get('categories', [])
                    if "local" in named_categories and r.get('country_code') == country:
                        if len(temp_results["local"]) < 150:
                            temp_results["local"].append(r)
                            
                    for cat in named_categories:
                        if cat in article_cats:
                            if len(temp_results[cat]) < 150:
                                temp_results[cat].append(r)

                should_write_cache = before is None and offset == 0
                if redis_client and should_write_cache:
                    for cat, cat_articles in temp_results.items():
                        if cat_articles:
                            try:
                                await redis_client.set(
                                    f"feed:v4:{country_key}:{cat}",
                                    orjson.dumps(cat_articles),
                                    ex=10800,
                                )
                            except Exception as e:
                                logger.warning("Redis cache write error for %s: %s", cat, e)

        # 6. High-Performance Deduplication and Viewed Filtering (Audit Recommendation)
        # We deduplicate by EXACT ID and Semantic Cluster (populated during ingestion).
        # We also filter out viewed articles from ALL sources (cache and DB) using Redis Set.
        viewed_ids: Set[str] = set()
        if user_id and redis_client:
            try:
                seen_key = f"user_seen_v2:{user_id}"
                # Retrieve all recently seen IDs for this user
                res = await redis_client.smembers(seen_key)
                if res:
                    viewed_ids = set(res)
            except Exception as e:
                logger.warning("Failed to fetch viewed_ids from Redis: %s", e)

        seen_ids: Set[str] = set()
        seen_clusters: Set[str] = set()
        unique_filtered = []
        
        for a in all_articles:
            aid = str(a['id'])
            cid = str(a['cluster_id']) if a.get('cluster_id') else None
            
            # Skip if exact ID seen OR similar story (Cluster) seen
            if aid in seen_ids or (cid and cid in seen_clusters):
                continue
            
            # Skip if user has already viewed this article
            if aid in viewed_ids:
                continue

            seen_ids.add(aid)
            if cid:
                seen_clusters.add(cid)
            unique_filtered.append(a)

        # 7. Final slice
        # If 'before' (cursor) is used, we generally don't want to skip with 'offset' 
        # unless explicitly requested relative to that cursor.
        actual_offset = offset if before is None else 0
        final_result = unique_filtered[actual_offset:actual_offset+limit]

        logger.info(
            f"Feed request: user={user_id} country={country} ({country_source}) "
            f"redis_cats={len(articles_by_cat)} merged={len(all_articles)} "
            f"filtered_views={len(viewed_ids)} returned={len(final_result)}"
        )
        
        return final_result

    except HTTPException:
        raise
    except Exception as e:
        logger.exception("Database error in get_feed")
        raise HTTPException(status_code=500, detail="Failed to fetch articles")


@router.post("/view")
async def track_view(
    article_id: UUID,
    request: Request,
    user: User = Depends(verify_supabase_jwt)
):
    """
    Records a view for the given article and user.
    Optimized: Buffers views in Redis to reduce DB write volume (Audit Recommendation).
    """
    redis_client = getattr(request.app.state, "redis_client", None)
    if redis_client:
        try:
            # 1. Store in a Redis Set for fast filtering in get_feed (no DB hits)
            seen_key = f"user_seen_v2:{user.id}"
            await redis_client.sadd(seen_key, str(article_id))
            # Set TTL of 3 days so the set doesn't grow indefinitely
            await redis_client.expire(seen_key, 259200)

            # 2. Buffer in a list for permanent DB flushing (Reading History)
            view_entry = f"{user.id}:{article_id}"
            await redis_client.rpush("pending_view_buffer", view_entry)
            return {"status": "buffered"}
        except Exception as e:
            logger.warning("Failed to buffer view in Redis: %s", e)
    
    # Fallback: if Redis is unavailable, we don't block the user but we might lose the view
    # or we could do a direct write. To strictly follow the audit, we prioritize the buffer.
    return {"status": "accepted"}


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
    ip = get_client_ip(request)
    
    country = await get_country_from_ip(ip)
    
    if country and user:
        max_retries = 2
        for attempt in range(max_retries):
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
                        # Invalidate user state cache
                        redis_client = getattr(request.app.state, "redis_client", None)
                        if redis_client:
                            await redis_client.delete(f"user_state:{user.id}")
                    break # Success
            except Exception as e:
                if attempt < max_retries - 1:
                    logger.warning(f"Failed to save background detected country (attempt {attempt+1}/{max_retries}): {e}")
                    await asyncio.sleep(0.5)
                    continue
                logger.warning(f"Failed to save background detected country after retries: {e}")
            
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
    
    max_retries = 3
    for attempt in range(max_retries):
        try:
            async with db_pool.acquire() as conn:
                # We use a single query with a check and swap.
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
        except (asyncpg.PostgresError, OSError) as e:
            if attempt < max_retries - 1:
                logger.warning(f"Database operation failed in toggle_favorite (attempt {attempt+1}/{max_retries}): {e}. Retrying...")
                await asyncio.sleep(0.2 * (2 ** attempt))
                continue
            logger.error("Error toggling favorite: %s", e)
            raise HTTPException(status_code=500, detail="Failed to toggle favorite")
