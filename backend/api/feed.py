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


class Diversifier:
    """
    Interleaves articles from multiple buckets while enforcing diversity rules.
    Designed to be extensible for future personalization (likes/dislikes).
    """
    def __init__(self, buckets: List[List[dict]], ratios: List[float], max_consecutive_cat: int = 3, max_consecutive_source: int = 2, ignore_cat_limit: bool = False):
        self.buckets = [list(b) for b in buckets]
        self.ratios = ratios
        self.max_consecutive_cat = max_consecutive_cat
        self.max_consecutive_source = max_consecutive_source
        self.ignore_cat_limit = ignore_cat_limit
        
        self.last_categories: List[str] = []
        self.last_sources: List[str] = []
        
    def _is_diverse(self, article: dict) -> bool:
        # Category Guard - bypassed if ignore_cat_limit is True (e.g. for specific category pages)
        if not self.ignore_cat_limit:
            cats = article.get("categories") or ["unknown"]
            primary_cat = cats[0]
            if len(self.last_categories) >= self.max_consecutive_cat:
                if all(c == primary_cat for c in self.last_categories[-self.max_consecutive_cat:]):
                    return False
                
        # Source Guard
        source = article.get("source_name") or "unknown"
        if len(self.last_sources) >= self.max_consecutive_source:
            if all(s == source for s in self.last_sources[-self.max_consecutive_source:]):
                return False
                
        return True

    def _update_state(self, article: dict):
        cats = article.get("categories") or ["unknown"]
        self.last_categories.append(cats[0])
        self.last_sources.append(article.get("source_name") or "unknown")
        
        # Keep window size small
        if len(self.last_categories) > 5: self.last_categories.pop(0)
        if len(self.last_sources) > 5: self.last_sources.pop(0)

    def interleave(self, limit: int) -> List[dict]:
        result = []
        # Normalization of ratios not needed if they sum to ~1, but we use a round-robin approach
        # we try to fulfill the ratio over the course of the feed.
        
        bucket_indices = [0] * len(self.buckets)
        
        # We'll do a simple round-robin for the 33/33/33 case
        # For more complex ratios, a weighted scheduler would be better.
        while len(result) < limit:
            added_in_round = False
            for i in range(len(self.buckets)):
                bucket = self.buckets[i]
                start_idx = bucket_indices[i]
                
                # Search for the first diverse article in this bucket
                found_idx = -1
                for j in range(start_idx, len(bucket)):
                    candidate = bucket[j]
                    if self._is_diverse(candidate):
                        found_idx = j
                        break
                
                if found_idx != -1:
                    article = bucket.pop(found_idx)
                    result.append(article)
                    self._update_state(article)
                    added_in_round = True
                    if len(result) >= limit: break
                else:
                    # If we can't find a diverse article in this bucket, 
                    # we might have to relax the rules or just move on.
                    # For now, if a bucket is exhausted of diverse options, we just skip it.
                    pass
            
            if not added_in_round:
                # All buckets are either empty or have no diverse options left. 
                # Relax guards or break.
                break
        
        return result


def _get_rank_tuple(article: dict, preferred_country: Optional[str], interest_categories: List[str]) -> tuple:
    """
    Returns a sortable tuple for intra-bucket ranking.
    """
    rank_score = article.get("ranking_score") or 0.0
    return (-rank_score,)


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

                    # Loop up to 5 times to skip over any DB-missing IDs.
                    # Without this, a batch of stale Redis IDs returns articles=[]
                    # while has_more=True, which permanently halts client pagination.
                    ordered_articles = []
                    final_start_idx = start_idx
                    max_skip_attempts = 5

                    for attempt in range(max_skip_attempts):
                        paged_ids = article_ids[final_start_idx : final_start_idx + limit]
                        if not paged_ids:
                            # Truly exhausted the session
                            break

                        async with db_pool.acquire() as conn:
                            records = await conn.fetch(
                                f"SELECT {ARTICLE_COLUMNS} FROM articles WHERE id = ANY($1::uuid[])",
                                [UUID(aid) for aid in paged_ids]
                            )

                        id_to_record = {str(r['id']): r for r in records}
                        batch_articles = []
                        for aid in paged_ids:
                            if aid in id_to_record:
                                r = dict(id_to_record[aid])
                                r['published_at'] = r['published_at'].isoformat() if r.get('published_at') else None
                                r['created_at'] = r['created_at'].isoformat() if r.get('created_at') else None
                                r['id'] = str(r['id'])
                                r['cluster_id'] = str(r['cluster_id']) if r.get('cluster_id') else None
                                batch_articles.append(r)

                        if batch_articles:
                            ordered_articles = batch_articles
                            break
                        else:
                            # All IDs in this batch are missing from DB — skip ahead
                            missing_count = len(paged_ids)
                            logger.warning(
                                f"Feed Session: {missing_count} IDs missing from DB "
                                f"(session={session_id}, attempt={attempt+1}). Skipping ahead."
                            )
                            final_start_idx += limit

                    expires_at = (datetime.now() + timedelta(hours=4)).isoformat()

                    # If no articles were found after all skip attempts, the session is
                    # effectively exhausted (either truly out of IDs, or all remaining
                    # IDs are missing from the DB). Signal the client to stop or refresh.
                    if not ordered_articles:
                        logger.warning(
                            f"Feed Session Exhausted after {max_skip_attempts} skip attempts: "
                            f"session={session_id} cursor={cursor}"
                        )
                        return {
                            "articles": [],
                            "session_id": session_id,
                            "next_cursor": None,
                            "has_more": False,
                            "expires_at": expires_at
                        }

                    # Success: compute the cursor for the NEXT page from where we found articles.
                    next_start_idx = final_start_idx + limit
                    has_more = next_start_idx < len(article_ids)
                    next_cursor = str(next_start_idx) if has_more else None

                    logger.info(f"Feed Session Hit: session={session_id} cursor={cursor} items={len(ordered_articles)}")
                    return {
                        "articles": ordered_articles,
                        "session_id": session_id,
                        "next_cursor": next_cursor,
                        "has_more": has_more,
                        "expires_at": expires_at
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

        # 3. Internal Interest Logic
        # If a specific category is requested, we override personal interests to focus 
        # strictly on that category, applying the ranking boost and bypassing diversification limits.
        is_category_page = category is not None
        
        if is_category_page:
            interests = [category]
            topic_interests = [category]
            has_local_interest = True # For category pages, we check local bucket if applicable
            category_boost = category
        else:
            user_interests = user_state.get("interests", []) if user_state else []
            interests = user_interests
            has_local_interest = "local" in user_interests
            topic_interests = [i for i in user_interests if i != "local"]
            category_boost = None

        # 4. Bucketized Fetching (Portfolio Interleave Architecture)
        async def fetch_bucket(conn, where_clause, params, label, category_boost: Optional[str] = None):
            order_by = "ranking_score DESC, published_at DESC"
            if category_boost:
                # Prioritize articles where the requested category is the PRIMARY category (index 1)
                order_by = f"(categories[1] = '{category_boost}') DESC, {order_by}"

            query = f"""
                SELECT {ARTICLE_COLUMNS}
                FROM articles
                WHERE {where_clause}
                ORDER BY {order_by}
                LIMIT 150
            """
            recs = await conn.fetch(query, *params)
            articles = []
            for r in recs:
                dict_r = dict(r)
                dict_r['published_at'] = dict_r['published_at'].isoformat() if dict_r.get('published_at') else None
                dict_r['created_at'] = dict_r['created_at'].isoformat() if dict_r.get('created_at') else None
                dict_r['id'] = str(dict_r['id'])
                dict_r['cluster_id'] = str(dict_r['cluster_id']) if dict_r.get('cluster_id') else None
                articles.append(dict_r)
            logger.info(f"Bucket '{label}' fetched: {len(articles)} items")
            return articles

        # Seen filter for all buckets
        viewed_ids: Set[str] = set()
        if user_id and redis_client:
            seen_res = await redis_client.smembers(f"user_seen_v2:{user_id}")
            if seen_res: viewed_ids = set(seen_res)

        common_where = "published_at > NOW() - INTERVAL '72 hours'"
        if viewed_ids:
            common_where += f" AND id NOT IN ({','.join([f'${i+1}' for i in range(len(viewed_ids))])})"
            viewed_params = [UUID(vid) for vid in viewed_ids]
        else:
            viewed_params = []

        async with db_pool.acquire() as conn:
            # Bucket 1: Local (Only if user has "local" interest or anon)
            # Must match user's current country AND fall within their selected interests.
            local_bucket = await fetch_bucket(
                conn, 
                f"{common_where} AND country_code = ${len(viewed_params)+1} AND categories && ${len(viewed_params)+2}::text[]", 
                viewed_params + [country, interests], 
                "Local",
                category_boost=category_boost
            ) if (country and has_local_interest and interests) else []
            
            # Bucket 2: Interests (Topic-based, Global Perspective)
            # Pulls from topics the user is interested in, but only where the news is truly international (NULL country).
            interest_bucket = await fetch_bucket(
                conn, 
                f"{common_where} AND categories && ${len(viewed_params)+1}::text[] AND country_code IS NULL", 
                viewed_params + [topic_interests], 
                "Interests",
                category_boost=category_boost
            ) if topic_interests else []
            
            # Bucket 3: World (Strictly International Headlines)
            # Pulls global news (NULL country), but ONLY if it matches the user's interest profile.
            world_bucket = await fetch_bucket(
                conn, 
                f"{common_where} AND country_code IS NULL AND categories && ${len(viewed_params)+1}::text[]", 
                viewed_params + [interests], 
                "World",
                category_boost=category_boost
            ) if interests else []

        # Deduplicate across buckets (prefer Interests > Local > World)
        all_ids = set()
        def dedupe(bucket):
            unique = []
            for a in bucket:
                if a['id'] not in all_ids:
                    unique.append(a)
                    all_ids.add(a['id'])
            return unique
        
        final_interest = dedupe(interest_bucket)
        final_local = dedupe(local_bucket)
        final_world = dedupe(world_bucket)

        # 5. Dynamic Interleave Ratio Calculation
        # We determine which buckets are active to rebalance the 100% weight.
        active_buckets = []
        active_ratios = []
        
        if final_interest:
            active_buckets.append(final_interest)
        if final_local:
            active_buckets.append(final_local)
        if final_world:
            active_buckets.append(final_world)
            
        num_active = len(active_buckets)
        if num_active > 0:
            # Rebalance evenly: if 3 buckets -> 0.33 each, if 2 -> 0.50 each, if 1 -> 1.0
            active_ratios = [1.0 / num_active] * num_active
        else:
            # Fallback (should not happen due to World bucket)
            active_buckets = [[]]
            active_ratios = [1.0]

        # 6. Interleave using Diversifier
        diversifier = Diversifier(
            buckets=active_buckets,
            ratios=active_ratios,
            max_consecutive_cat=3,
            max_consecutive_source=2,
            ignore_cat_limit=is_category_page # Relax category guards on specific category pages
        )
        
        session_articles = diversifier.interleave(limit=300)

        # 5. Global Deduplication (just in case)
        # (Already handled by the dedupe function above)

        # 6. Session Creation
        new_session_id = str(uuid4())
        
        if redis_client:
            session_key = f"session_articles:{new_session_id}"
            all_ids_list = [str(a['id']) for a in session_articles]
            await redis_client.set(session_key, orjson.dumps(all_ids_list), ex=14400) # 4 Hour TTL

        final_result = session_articles[:limit]
        has_more = len(session_articles) > limit
        next_cursor = str(limit) if has_more else None
        expires_at = (datetime.now() + timedelta(hours=4)).isoformat()

        logger.info(f"New Diversified Feed Session: session={new_session_id} items={len(session_articles)}")
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
