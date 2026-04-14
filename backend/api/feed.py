import logging
import asyncio
import re
import sys
from datetime import datetime, timedelta
from urllib.parse import urlparse
from fastapi import APIRouter, HTTPException, Depends, Query, Request, BackgroundTasks
from uuid import UUID, uuid4
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
    published_at, created_at, categories, subcategory, is_paywalled, country_code, ranking_score, cluster_id, is_major_source
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


def _get_rank_tuple(article: dict, preferred_country: Optional[str], interest_categories: List[str]) -> tuple:
    """
    Returns a sortable tuple that mirrors the SQL ORDER BY logic for mid-layer merging.
    SQL Order: country_boost ASC, category_priority ASC, trending_tier ASC, major_source_tier ASC, ranking_score DESC
    """
    country_code = article.get("country_code")
    categories = article.get("categories") or []
    rank_score = article.get("ranking_score") or 0.0
    is_major = article.get("is_major_source", False)

    country_boost = 0 if (preferred_country and country_code == preferred_country) else 1
    
    # Priority if the primary category matches one of the user's interests
    cat_priority = 0 if (categories and categories[0] in interest_categories) else 1
    
    # Simple tiering: high score articles first
    trending_tier = 0 if rank_score > 0 else 1
    major_tier = 0 if is_major else 1
    
    # We use negative ranking_score for ASC sorting to achieve DESC behavior in the tuple
    return (country_boost, cat_priority, trending_tier, major_tier, -rank_score)


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
        "interests": sorted([r["category"] for r in interest_records]),
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
    session_id: Optional[str] = Query(None, description="Active session ID for deterministic pagination"),
    cursor: Optional[str] = Query(None, description="Next page cursor (offset)"),
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
        
        # 0. Session Handling (Recommendation 1.2)
        # If a session_id is provided, we try to fulfill the request from the session cache
        if session_id and redis_client:
            session_key = f"session_articles:{session_id}"
            try:
                cached_ids_data = await redis_client.get(session_key)
                if cached_ids_data:
                    article_ids = orjson.loads(cached_ids_data)
                    start_idx = int(cursor) if cursor and cursor.isdigit() else 0
                    paged_ids = article_ids[start_idx : start_idx + limit]
                    
                    if paged_ids:
                        # Fetch the articles from DB (or global cache) for these specific IDs
                        async with db_pool.acquire() as conn:
                            records = await conn.fetch(
                                f"SELECT {ARTICLE_COLUMNS} FROM articles WHERE id = ANY($1::uuid[])",
                                [UUID(aid) for aid in paged_ids]
                            )
                        
                        # Maintain the session's deterministic order
                        id_to_record = {str(r['id']): r for r in records}
                        ordered_articles = []
                        for aid in paged_ids:
                            if aid in id_to_record:
                                r = dict(id_to_record[aid])
                                r['published_at'] = r['published_at'].isoformat() if r.get('published_at') else None
                                r['created_at'] = r['created_at'].isoformat() if r.get('created_at') else None
                                r['id'] = str(r['id'])
                                r['cluster_id'] = str(r['cluster_id']) if r.get('cluster_id') else None
                                ordered_articles.append(r)

                        has_more = (start_idx + limit) < len(article_ids)
                        next_cursor = str(start_idx + limit) if has_more else None
                        expires_at = (datetime.now() + timedelta(hours=4)).isoformat()

                        logger.info(f"Feed Session Hit: session={session_id} cursor={cursor} items={len(ordered_articles)}")
                        return {
                            "articles": ordered_articles,
                            "session_id": session_id,
                            "next_cursor": next_cursor,
                            "has_more": has_more,
                            "expires_at": expires_at
                        }
                    else:
                        logger.info(f"Feed Session Exhausted: session={session_id} cursor={cursor}")
                        return {
                            "articles": [],
                            "session_id": session_id,
                            "next_cursor": None,
                            "has_more": False,
                            "expires_at": (datetime.now() + timedelta(hours=4)).isoformat()
                        }
                else:
                    logger.warning(f"Feed Session Expired/Missing: session={session_id}. Starting new session.")
            except Exception as e:
                logger.error(f"Error serving session-based feed: {e}")

        # 1. Parallelize Geo-IP Detection and User State Fetch
        geo_task = get_country_from_ip(ip) if (not country or country.lower() == 'auto') else asyncio.sleep(0)
        state_task = get_user_state(str(user_id), db_pool, redis_client) if user_id else asyncio.sleep(0)
        
        gathered = await asyncio.gather(geo_task, state_task)
        detected_country = gathered[0] if isinstance(gathered[0], str) else None
        user_state = gathered[1] if isinstance(gathered[1], dict) else None
        
        # 2. Determine Country & Categories
        if not country or country.lower() == 'auto':
            if user_state and user_state.get("preferred_country"):
                country = user_state["preferred_country"]
            elif detected_country:
                country = detected_country
            else:
                country = None

        categories_to_fetch = [category] if category else (user_state.get("interests") if user_state else ["all"])
        if not categories_to_fetch: categories_to_fetch = ["all"]
        categories_to_fetch = [str(c).strip().lower() for c in categories_to_fetch]
            
        # 3. Fetch from Global Redis (Warm Cache)
        country_key = country or 'all'
        articles_by_cat = {}
        missing_categories = []
        required_cached_count = 150 # Fetch a healthy buffer for sessionization
        
        if redis_client:
            keys = [f"feed:v4:{country_key}:{cat}" for cat in categories_to_fetch]
            try:
                cached_results = await asyncio.gather(*[redis_client.get(k) for k in keys])
                for cat, cached in zip(categories_to_fetch, cached_results):
                    if cached:
                        cat_articles = orjson.loads(cached)
                        articles_by_cat[cat] = cat_articles
                        if len(cat_articles) < required_cached_count:
                            missing_categories.append(cat)
                    else:
                        missing_categories.append(cat)
            except Exception as e:
                logger.warning("Redis warm-cache fetch error: %s", e)
                missing_categories = list(categories_to_fetch)
        else:
            missing_categories = list(categories_to_fetch)
        
        # 4. Fallback to DB for missing/sparse categories
        all_articles = []
        for cat in categories_to_fetch:
            if cat in articles_by_cat:
                all_articles.extend(articles_by_cat[cat])
        
        if missing_categories:
            named_categories = [c for c in missing_categories if c != "all"]
            params = [country if (country and country != 'all') else None]
            where_clauses = []
            
            cat_params_idx = None
            if "all" not in missing_categories:
                cat_params_idx = len(params) + 1
                params.append(named_categories)
                where_clauses.append(f"categories && ${cat_params_idx}::text[]")
            
            # Viewed filtering (Partial)
            if user_id:
                where_clauses.append(f"id NOT IN (SELECT article_id FROM article_views WHERE user_id = ${len(params) + 1}::uuid ORDER BY viewed_at DESC LIMIT 300)")
                params.append(user_id)
            
            where_sql = " WHERE " + " AND ".join(where_clauses) if where_clauses else ""
            country_boost = "CASE WHEN $1::text IS NOT NULL AND country_code = $1 THEN 0 ELSE 1 END"
            category_priority = f"CASE WHEN categories[1] = ANY(${cat_params_idx}::text[]) THEN 0 ELSE 1 END" if cat_params_idx else "0"

            batch_query = f"""
                SELECT {ARTICLE_COLUMNS},
                       {country_boost} as country_boost_val,
                       {category_priority} as category_priority_val
                FROM articles
                {where_sql}
                ORDER BY country_boost_val ASC, category_priority_val ASC, ranking_score DESC, published_at DESC
                LIMIT 300
            """
            async with db_pool.acquire() as conn:
                records = await conn.fetch(batch_query, *params)
            
            for record in records:
                r = dict(record)
                r['published_at'] = r['published_at'].isoformat() if r.get('published_at') else None
                r['created_at'] = r['created_at'].isoformat() if r.get('created_at') else None
                r['id'] = str(r['id'])
                r['cluster_id'] = str(r['cluster_id']) if r.get('cluster_id') else None
                all_articles.append(r)

        # 5. Global Ranking and Deduplication
        viewed_ids: Set[str] = set()
        if user_id and redis_client:
            seen_res = await redis_client.smembers(f"user_seen_v2:{user_id}")
            if seen_res: viewed_ids = set(seen_res)

        seen_ids, seen_clusters = set(), set()
        unique_filtered = []
        for a in all_articles:
            aid, cid = str(a['id']), str(a['cluster_id']) if a.get('cluster_id') else None
            if aid in seen_ids or (cid and cid in seen_clusters) or aid in viewed_ids:
                continue
            seen_ids.add(aid)
            if cid: seen_clusters.add(cid)
            unique_filtered.append(a)

        unique_filtered.sort(key=lambda x: _get_rank_tuple(x, country, categories_to_fetch))

        # 6. Session Creation (New)
        new_session_id = str(uuid4())
        session_articles = unique_filtered[:300] # Cap session size
        
        if redis_client:
            session_key = f"session_articles:{new_session_id}"
            all_ids = [str(a['id']) for a in session_articles]
            await redis_client.set(session_key, orjson.dumps(all_ids), ex=14400) # 4 Hour TTL

        final_result = session_articles[:limit]
        has_more = len(session_articles) > limit
        next_cursor = str(limit) if has_more else None
        expires_at = (datetime.now() + timedelta(hours=4)).isoformat()

        logger.info(f"New Feed Session Created: session={new_session_id} items={len(session_articles)}")
        return {
            "articles": final_result,
            "session_id": new_session_id,
            "next_cursor": next_cursor,
            "has_more": has_more,
            "expires_at": expires_at
        }

    except Exception as e:
        import traceback
        traceback.print_exc(file=sys.stderr)
        logger.exception("Error in get_feed")
        raise HTTPException(status_code=500, detail=f"Failed to fetch articles: {str(e)}")


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
