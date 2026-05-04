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
from ..core.security import limiter, verify_supabase_jwt, User, get_client_ip, verify_app_check, get_feed_rate_limit
from ..core.geo import get_country_from_ip
from ..services.ingestion import fetch_local_news_on_demand
from ..services.personalization import schedule_debounced_personalization_update

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
    published_at, created_at, categories, subcategory, is_paywalled, country_code, ranking_score, cluster_id, is_major_source,
    'article' as item_type
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
        self.current_counts = [0] * len(self.buckets)
        
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
        """
        Interleaves articles from buckets using a weighted scheduler to maintain
        the requested ratios (e.g., 70/20/10) while enforcing diversity.
        """
        result = []
        
        while len(result) < limit:
            # Find the bucket that is most "behind" its target ratio.
            # We use (current_count / ratio) as a score; lowest score wins.
            best_bucket_idx = -1
            min_score = float('inf')
            
            # We sort indices by score so we can try the best one first, 
            # and if diversity fails, try the next best one.
            candidates = []
            for i in range(len(self.buckets)):
                if not self.buckets[i]:
                    continue
                score = self.current_counts[i] / self.ratios[i]
                candidates.append((score, i))
            
            candidates.sort() # Sort by score ascending
            
            added_in_this_step = False
            for _, i in candidates:
                bucket = self.buckets[i]
                
                # Look for the first article in this bucket that satisfies diversity
                found_idx = -1
                for j in range(len(bucket)):
                    if self._is_diverse(bucket[j]):
                        found_idx = j
                        break
                
                if found_idx != -1:
                    article = bucket.pop(found_idx)
                    result.append(article)
                    self._update_state(article)
                    self.current_counts[i] += 1
                    added_in_this_step = True
                    break
            
            if not added_in_this_step:
                # If no bucket can provide a diverse article, but buckets aren't empty,
                # we have to "relax" the rules. We take the best-ratio bucket's first item.
                if not candidates:
                    break # Truly empty
                
                # Forced pick from the most-needed bucket to avoid getting stuck
                _, i = candidates[0]
                article = self.buckets[i].pop(0)
                result.append(article)
                self._update_state(article)
                self.current_counts[i] += 1

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
    """Fetch user country preference + interests, with Redis caching."""
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
        profile = await conn.fetchrow(
            "SELECT preferred_country, interest_embedding::text as interest_embedding FROM user_profiles WHERE user_id = $1", user_id
        )
        interest_records = await conn.fetch(
            "SELECT category FROM user_interests WHERE user_id = $1", user_id
        )

    # Parse interest_embedding string (e.g. "[0.1, 0.2]") to list
    profile_data = dict(profile) if profile else {}
    emb_text = profile_data.get("interest_embedding")
    interest_embedding = orjson.loads(emb_text) if emb_text else None

    state = {
        "preferred_country": profile_data.get("preferred_country"),
        "interest_embedding": interest_embedding,
        "interests": sorted([r["category"] for r in interest_records]),
    }

    if redis_client:
        try:
            await redis_client.set(cache_key, orjson.dumps(state), ex=300) # 5 min TTL
        except Exception as e:
            logger.warning("Redis user_state cache set error: %s", e)

    return state


@router.get("")
@limiter.limit(get_feed_rate_limit)
async def get_feed(
    request: Request,
    category: Optional[str] = Query(None, description="Filter articles by category"),
    country: Optional[str] = Query(None, description="Country code for local news (e.g. KE, US)"),
    limit: int = Query(30, ge=1, le=100, description="Number of items to return"),
    session_id: Optional[str] = Query(None, description="Active session ID for deterministic pagination"),
    cursor: Optional[str] = Query(None, description="Next page cursor (offset)"),
    background_tasks: BackgroundTasks = BackgroundTasks(),
    db_pool: asyncpg.Pool = Depends(get_db),
    user: Optional[User] = Depends(verify_supabase_jwt),
    _app_check: dict = Depends(verify_app_check)
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

        if country:
            # Trigger background refresh for this country if it hasn't been fetched recently.
            # This ensures that even if our cron is slow, a user checking their local tab triggers an update.
            background_tasks.add_task(fetch_local_news_on_demand, country, db_pool)
        
        # 3. Internal Interest Logic
        # If a specific category is requested, we override personal interests to focus 
        # strictly on that category, applying the ranking boost and bypassing diversification limits.
        is_category_page = category is not None
        is_local_request = (category == 'local')
        
        if is_category_page:
            if is_local_request:
                # For the 'local' page, we don't filter by the 'local' string in categories
                # because articles are usually tagged with topics (politics, tech) and country_code.
                interests = [] 
                topic_interests = []
                has_local_interest = True
                category_boost = None 
            else:
                interests = [category]
                topic_interests = [category]
                has_local_interest = False
                category_boost = category
        else:
            user_interests = user_state.get("interests", []) if user_state else []
            interests = user_interests
            has_local_interest = "local" in user_interests
            topic_interests = [i for i in user_interests if i != "local"]
            category_boost = None

        # 4. Bucketized Fetching (Portfolio Interleave Architecture)
        async def fetch_bucket(conn, where_clause, params, label, order_by=None, category_boost: Optional[str] = None):
            if not order_by:
                # Primary ranking logic: Major Sources > Ranking Score > Recency
                order_by = "is_major_source DESC, ranking_score DESC, published_at DESC"
            
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
                
                # Prepend 'local' category dynamically if the article matches the user's country context.
                # This ensures consistent UI behavior across platforms without requiring manual DB tagging for every topic.
                if country and dict_r.get('country_code') == country.upper():
                    cats = list(dict_r.get('categories') or [])
                    if 'local' not in cats:
                        dict_r['categories'] = ['local'] + cats

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
            common_where += f" AND id NOT IN ({','.join([f'${i+1}::uuid' for i in range(len(viewed_ids))])})"
            viewed_params = [UUID(vid) for vid in viewed_ids]
        else:
            viewed_params = []

        # Geographic Filter: Only show global news or news from the user's country
        geo_filter = " AND (country_code IS NULL"
        geo_params = []
        if country:
            # We'll calculate the index for country dynamically later to avoid confusion
            pass
        else:
            geo_filter += ")"

        async with db_pool.acquire() as conn:
            # Bucket 1: Personalized (70%)
            if user_state and user_state.get("interest_embedding"):
                # Index calculation: viewed_params($1..$N), [interests($N+1)], embedding($N+2), country($N+3)
                p_params = list(viewed_params)
                
                if not is_local_request:
                    p_where = f"{common_where} AND categories && ${len(p_params)+1}::text[]"
                    p_params.append(interests)
                else:
                    p_where = common_where
                
                # Embedding index depends on whether interests were added
                emb_idx = len(p_params) + 1
                p_params.append(orjson.dumps(user_state["interest_embedding"]).decode())
                
                if country:
                    if is_local_request:
                        p_where += f" AND country_code = ${len(p_params)+1}::text"
                    else:
                        p_where += f" AND (country_code IS NULL OR country_code = ${len(p_params)+1}::text)"
                    p_params.append(country)
                else:
                    p_where += " AND country_code IS NULL"

                personalized_bucket = await fetch_bucket(
                    conn,
                    p_where,
                    p_params,
                    "Personalized",
                    order_by=f"embedding <=> ${emb_idx}::vector",
                    category_boost=category_boost
                )
            else:
                # Cold start: rely on category matches
                p_params = list(viewed_params)
                if not is_local_request:
                    p_where = f"{common_where} AND categories && ${len(p_params)+1}::text[]"
                    p_params.append(interests)
                else:
                    p_where = common_where
                
                if country:
                    if is_local_request:
                        p_where += f" AND country_code = ${len(p_params)+1}::text"
                    else:
                        p_where += f" AND (country_code IS NULL OR country_code = ${len(p_params)+1}::text)"
                    p_params.append(country)
                else:
                    p_where += " AND country_code IS NULL"

                personalized_bucket = await fetch_bucket(
                    conn,
                    p_where,
                    p_params,
                    "Personalized (Cold)",
                    category_boost=category_boost
                )

            # Bucket 2: Trending (20%)
            # Must respect user interests while being high-ranking
            t_params = list(viewed_params)
            if not is_local_request:
                t_where = f"{common_where} AND ranking_score > 0.1 AND categories && ${len(t_params)+1}::text[]"
                t_params.append(interests)
            else:
                t_where = f"{common_where} AND ranking_score > 0.1"
            
            if country:
                if is_local_request:
                    t_where += f" AND country_code = ${len(t_params)+1}::text"
                else:
                    t_where += f" AND (country_code IS NULL OR country_code = ${len(t_params)+1}::text)"
                t_params.append(country)
            else:
                t_where += " AND country_code IS NULL"

            trending_bucket = await fetch_bucket(
                conn,
                t_where,
                t_params,
                "Trending"
            )

            # Bucket 3: Discovery (10%)
            # Random selection to break the filter bubble.
            # When on a category page, we must still respect the category choice.
            d_params = list(viewed_params)
            if is_category_page and not is_local_request:
                d_where = f"{common_where} AND categories && ${len(d_params)+1}::text[]"
                d_params.append(interests)
            else:
                d_where = common_where
            
            if country:
                if is_local_request:
                    d_where += f" AND country_code = ${len(d_params)+1}::text"
                else:
                    d_where += f" AND (country_code IS NULL OR country_code = ${len(d_params)+1}::text)"
                d_params.append(country)
            else:
                d_where += " AND country_code IS NULL"

            discovery_bucket = await fetch_bucket(
                conn,
                d_where,
                d_params,
                "Discovery",
                order_by="RANDOM()"
            )

            # Bucket 4: Global Trending (Phase 2 fallback / Cold start filler)
            # High quality trending news. Constrained by category if requested.
            gt_params = list(viewed_params)
            if is_category_page and not is_local_request:
                gt_where = f"{common_where} AND ranking_score > 0.3 AND categories && ${len(gt_params)+1}::text[]"
                gt_params.append(interests)
            else:
                gt_where = f"{common_where} AND ranking_score > 0.3"
                if interests and not is_local_request:
                    # For general feed, we specifically look for trending news OUTSIDE their interests for variety
                    gt_where += f" AND NOT (categories && ${len(gt_params)+1}::text[])"
                    gt_params.append(interests)
            
            # Global Trending should NOT be restricted by country — it's the source for world variety.
            # We already have common_where (recency + optional paywall filter).
            pass
            
            global_trending_bucket = await fetch_bucket(
                conn,
                gt_where,
                gt_params,
                "Global Trending"
            )

        # Deduplicate and Split across buckets (prefer Personalized > Trending > Discovery)
        all_ids = set()
        # In cold start (new user with no interests), we prioritize global trending content.
        # However, for explicit category pages (like 'Local'), we want to see content from all buckets.
        is_cold_start = not interests and not is_category_page
        interest_set = set(interests)
        
        def process_bucket(bucket):
            primary = []
            secondary = []
            for a in bucket:
                if a['id'] not in all_ids:
                    all_ids.add(a['id'])
                    # Check if the primary category (index 0) is in user interests
                    cats = a.get('categories') or []
                    # In cold start OR on a specific category page, everything in the initial buckets is considered primary
                    if is_cold_start or is_category_page or (cats and cats[0] in interest_set):
                        primary.append(a)
                    else:
                        secondary.append(a)
            return primary, secondary
        
        p_primary, p_secondary = process_bucket(personalized_bucket)
        t_primary, t_secondary = process_bucket(trending_bucket)
        d_primary, d_secondary = process_bucket(discovery_bucket)
        
        # Global trending articles are always secondary (unless it's a cold start)
        gt_primary, gt_secondary = process_bucket(global_trending_bucket)

        # 5. Two-Phase Diversification
        
        # --- Phase 1: Primary Matches ---
        active_buckets_p = []
        active_ratios_p = []
        
        # If cold start, we use global trending as the core of the primary feed
        if is_cold_start and gt_primary:
            active_buckets_p.append(gt_primary)
            active_ratios_p.append(1.0)
        else:
            if p_primary:
                active_buckets_p.append(p_primary)
                active_ratios_p.append(0.7)
            if t_primary:
                active_buckets_p.append(t_primary)
                active_ratios_p.append(0.2)
            if d_primary:
                active_buckets_p.append(d_primary)
                active_ratios_p.append(0.1)
            
        if active_ratios_p:
            total_r = sum(active_ratios_p)
            active_ratios_p = [r/total_r for r in active_ratios_p]
            div_p = Diversifier(active_buckets_p, active_ratios_p, ignore_cat_limit=is_category_page)
            primary_results = div_p.interleave(limit=300)
        else:
            primary_results = []

        # --- Phase 2: Secondary Matches ---
        active_buckets_s = []
        active_ratios_s = []
        
        # Prioritize Global Trending in Phase 2
        if gt_secondary:
            active_buckets_s.append(gt_secondary)
            active_ratios_s.append(0.5)
            
        if p_secondary:
            active_buckets_s.append(p_secondary)
            active_ratios_s.append(0.35)
        if t_secondary:
            active_buckets_s.append(t_secondary)
            active_ratios_s.append(0.1)
        if d_secondary:
            active_buckets_s.append(d_secondary)
            active_ratios_s.append(0.05)
            
        if active_ratios_s:
            total_r = sum(active_ratios_s)
            active_ratios_s = [r/total_r for r in active_ratios_s]
            div_s = Diversifier(active_buckets_s, active_ratios_s, ignore_cat_limit=is_category_page)
            secondary_results = div_s.interleave(limit=300)
        else:
            secondary_results = []

        # --- Final Ranking Refinement ---
        # For new users/cold start, we want to ensure the top of the feed is strictly 
        # the best of the best across both phases before diversification noise takes over.
        if is_cold_start and primary_results:
            # Re-sort the very top of the feed by ranking score to avoid 
            # interleaving-induced quality drops (e.g. #2 being much worse than #3)
            top_slice = primary_results[:10]
            rest = primary_results[10:]
            top_slice.sort(key=lambda a: (a.get('is_major_source', False), a.get('ranking_score', 0.0)), reverse=True)
            primary_results = top_slice + rest

        # --- Assembly ---
        session_articles = primary_results
        
        # Insert marker if we have both primary and secondary content, 
        # or if we only have secondary content but the user has interests (meaning primary is exhausted).
        # We don't show the marker on specific category pages OR during cold start.
        show_marker = not is_category_page and not is_cold_start and secondary_results
        
        if show_marker:
            marker = {
                "id": "00000000-0000-0000-0000-000000000000",
                "title": "You're all caught up!",
                "summary": "You've seen all the latest stories from your selected categories. Here are some other interesting topics you might like.",
                "original_url": "https://currenta.tech",
                "image_url": None,
                "source_name": "Currenta",
                "published_at": datetime.now().isoformat(),
                "created_at": datetime.now().isoformat(),
                "categories": ["world"],
                "item_type": "exhaustion_marker",
                "ranking_score": 0.0,
                "is_paywalled": False,
                "is_major_source": True,
            }
            # Only append primary_results if they exist, otherwise we just start with the marker?
            # Actually, if primary_results is empty, the marker says "caught up" which is fine.
            session_articles.append(marker)
            session_articles.extend(secondary_results)
        elif is_cold_start:
            # In cold start, just combine everything seamlessly
            session_articles.extend(secondary_results)
        elif not primary_results and not secondary_results:
            session_articles = []
        elif not secondary_results:
            session_articles = primary_results

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



@router.delete("/user-state")
async def clear_user_state(
    request: Request,
    user: User = Depends(verify_supabase_jwt)
):
    """
    Invalidates the cached user state (interests, country) in Redis.
    Should be called when preferences change or upon login.
    """
    redis_client = getattr(request.app.state, "redis_client", None)
    if redis_client:
        try:
            cache_key = f"user_state:{user.id}"
            await redis_client.delete(cache_key)
            logger.info(f"Invalidated Redis cache for user_state:{user.id}")
            return {"status": "success", "message": "User state cache invalidated"}
        except Exception as e:
            logger.error(f"Failed to invalidate Redis cache: {e}")
            # Don't fail the request, just log it
    
    return {"status": "ignored", "message": "Redis not available or cache already empty"}


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
    """
    if not user:
        raise HTTPException(status_code=401, detail="Authentication required")
    
    async with db_pool.acquire() as conn:
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


@router.post("/like")
@limiter.limit("60/minute")
async def toggle_like(
    request: Request,
    article_id: UUID,
    db_pool: asyncpg.Pool = Depends(get_db),
    user: User = Depends(verify_supabase_jwt)
):
    """
    Toggles the like status of an article for the user.
    Syncs with Supabase 'article_likes' table which triggers vector recalculation.
    """
    if not user:
        raise HTTPException(status_code=401, detail="Authentication required")
    
    async with db_pool.acquire() as conn:
        exists = await conn.fetchval(
            "SELECT 1 FROM article_likes WHERE user_id = $1 AND article_id = $2",
            user.id, str(article_id)
        )
        
        if exists:
            await conn.execute(
                "DELETE FROM article_likes WHERE user_id = $1 AND article_id = $2",
                user.id, str(article_id)
            )
            # Debounced background update
            schedule_debounced_personalization_update(user.id)
            return {"status": "unliked"}
        else:
            await conn.execute(
                "INSERT INTO article_likes (user_id, article_id) VALUES ($1, $2)",
                user.id, str(article_id)
            )
            # Debounced background update
            schedule_debounced_personalization_update(user.id)
            return {"status": "liked"}


@router.get("/liked")
@limiter.limit("30/minute")
async def get_liked_articles(
    request: Request,
    limit: int = Query(30, ge=1, le=100),
    offset: int = Query(0, ge=0),
    db_pool: asyncpg.Pool = Depends(get_db),
    user: User = Depends(verify_supabase_jwt)
):
    """
    Returns the articles liked by the user, newest first.
    Joined with full article metadata.
    """
    if not user:
        raise HTTPException(status_code=401, detail="Authentication required")
    
    async with db_pool.acquire() as conn:
        query = f"""
            SELECT {ARTICLE_COLUMNS}
            FROM articles a
            JOIN article_likes l ON a.id = l.article_id
            WHERE l.user_id = $1
            ORDER BY l.created_at DESC
            LIMIT $2 OFFSET $3
        """
        records = await conn.fetch(query, user.id, limit, offset)
        
        articles = []
        for r in records:
            dict_r = dict(r)
            dict_r['published_at'] = dict_r['published_at'].isoformat() if dict_r.get('published_at') else None
            dict_r['created_at'] = dict_r['created_at'].isoformat() if dict_r.get('created_at') else None
            dict_r['id'] = str(dict_r['id'])
            dict_r['cluster_id'] = str(dict_r['cluster_id']) if dict_r.get('cluster_id') else None
            articles.append(dict_r)
            
        return {
            "articles": articles,
            "has_more": len(articles) == limit,
            "next_offset": offset + limit if len(articles) == limit else None
        }
