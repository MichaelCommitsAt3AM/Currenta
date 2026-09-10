import logging
import asyncio
import httpx
import re
import orjson
from bs4 import BeautifulSoup
from datetime import datetime, timezone
from typing import List, Dict, Optional
from .ingestion import embed_text, ingest_from_url, is_junk_content, is_junk_url

logger = logging.getLogger(__name__)

# Google Trends RSS URLs
TRENDS_RSS_URLS = {
    "US": "https://trends.google.com/trending/rss?geo=US",
    "KE": "https://trends.google.com/trending/rss?geo=KE",
    "GB": "https://trends.google.com/trending/rss?geo=GB",
}

# ── trend_score decay ─────────────────────────────────────────────────────────
# trend_score is additive and capped (see the UPDATE in update_trending_scores),
# so without decay a story that briefly went viral keeps a high score for its
# entire 72h feed life and dominates ranking long after it stopped trending.
# update_trending_scores() multiplicatively decays every run: stories still
# trending are re-boosted in the same pass and stay near the cap; the rest fade.
TREND_SCORE_DECAY_FACTOR = 0.75            # applied once per update_trending_scores run (~hourly → half-life ≈ 2.4h)
TREND_SCORE_FLOOR = 0.5                    # post-decay values below this snap to 0 so the row leaves the "trending" tier
TREND_SCORE_DECAY_MIN_INTERVAL_SECONDS = 1800  # skip decay if it already ran this recently (jobs occasionally co-fire)
TREND_SCORE_DECAY_MAX_AGE_DAYS = 10        # bound the UPDATE scan; comfortably past /trending's 168h max window
_TREND_DECAY_LAST_RUN_KEY = "trending:decay:last_run_at"


def _decayed_trend_score(current: float) -> float:
    """Pure form of the SQL decay in _decay_trend_scores — one run's decay,
    with a floor that snaps small residuals to zero. Kept in Python so the
    behaviour is unit-testable without a database."""
    decayed = (current or 0.0) * TREND_SCORE_DECAY_FACTOR
    return 0.0 if decayed < TREND_SCORE_FLOOR else decayed


async def _decay_trend_scores(db_pool, redis_client=None) -> None:
    """Multiplicatively decay trend_score across recent articles once, so the
    score tracks *current* momentum. Best-effort: never raise into the caller —
    a failed decay must not block the boost pass that follows it."""
    now = datetime.now(timezone.utc)

    if redis_client:
        try:
            last_raw = await redis_client.get(_TREND_DECAY_LAST_RUN_KEY)
            if last_raw:
                last_run = datetime.fromisoformat(
                    last_raw.decode() if isinstance(last_raw, bytes) else last_raw
                )
                elapsed = (now - last_run).total_seconds()
                if elapsed < TREND_SCORE_DECAY_MIN_INTERVAL_SECONDS:
                    logger.info(
                        "Trend score decay skipped: ran %.0fs ago (< %ds)",
                        elapsed, TREND_SCORE_DECAY_MIN_INTERVAL_SECONDS,
                    )
                    return
        except Exception as e:
            logger.warning("Trend score decay: Redis interval check failed, proceeding: %s", e)

    try:
        async with db_pool.acquire() as conn:
            result = await conn.execute(
                """
                UPDATE articles
                SET trend_score = CASE
                        WHEN trend_score * $1 < $2 THEN 0
                        ELSE trend_score * $1
                    END
                WHERE trend_score > 0
                  AND published_at > NOW() - ($3 * INTERVAL '1 day')
                """,
                TREND_SCORE_DECAY_FACTOR, TREND_SCORE_FLOOR, TREND_SCORE_DECAY_MAX_AGE_DAYS,
            )
        logger.info("Trend score decay applied (factor=%.2f): %s", TREND_SCORE_DECAY_FACTOR, result)
    except Exception as e:
        logger.error("Trend score decay failed: %s", e)
        return

    if redis_client:
        try:
            await redis_client.set(_TREND_DECAY_LAST_RUN_KEY, now.isoformat(), ex=86400)
        except Exception as e:
            logger.warning("Trend score decay: failed to record last-run timestamp: %s", e)

async def fetch_google_trends(region: str = "US") -> List[Dict]:
    """
    Fetches and parses Google Trends RSS for a specific region.
    Returns a list of trending items with their traffic and anchor story.
    """
    url = TRENDS_RSS_URLS.get(region, TRENDS_RSS_URLS["US"])
    async with httpx.AsyncClient(follow_redirects=True) as client:
        try:
            res = await client.get(url, timeout=15.0)
            res.raise_for_status()
            xml = res.text
        except Exception as e:
            logger.error(f"Failed to fetch Google Trends RSS for {region}: {e}")
            return []

    soup = BeautifulSoup(xml, 'xml')
    items = soup.find_all('item')
    
    trending_items = []
    for item in items:
        try:
            query = item.title.text.strip()
            traffic_text = item.find('ht:approx_traffic').text if item.find('ht:approx_traffic') else "0"
            traffic = int(re.sub(r'[^0-9]', '', traffic_text))
            
            # Google Trends provides multiple news items (ht:news_item)
            news_items = item.find_all('ht:news_item')
            clean_stories = []
            
            for ni in news_items:
                ni_title = ni.find('ht:news_item_title').text if ni.find('ht:news_item_title') else ""
                ni_url = ni.find('ht:news_item_url').text if ni.find('ht:news_item_url') else ""

                # Fast URL pre-check to block betting/prediction links before any heavier processing.
                url_reason = is_junk_url(ni_url, ni_title, query)
                if url_reason:
                    logger.debug(f"[{region}] Skipping URL-junk story in trend '{query}': {ni_url} ({url_reason})")
                    continue
                
                # Verify if this specific news story is junk
                reason = is_junk_content(ni_title, query)
                if not reason:
                    clean_stories.append({"title": ni_title, "url": ni_url})
                else:
                    logger.debug(f"[{region}] Skipping junk story in trend '{query}': {ni_title} ({reason})")

            if not clean_stories:
                logger.info(f"[{region}] Skipping trend '{query}': No high-signal news stories found among {len(news_items)} items.")
                continue

            # Use the first clean story as the primary anchor for ingestion
            primary = clean_stories[0]
            
            trending_items.append({
                "query": query,
                "traffic": traffic,
                "anchor_title": primary["title"],
                "anchor_url": primary["url"],
                # We save all clean titles to help with semantic mapping context
                "context_text": " | ".join([s["title"] for s in clean_stories]),
                "region": region
            })
        except Exception as e:
            logger.warning(f"Error parsing trending item: {e}")
            continue
            
    return trending_items

async def log_trending_event(conn, region: str, query: str, action: str, traffic: int = None, anchor_title: str = None, anchor_url: str = None, match_count: int = 0, error_message: str = None):
    try:
        await conn.execute('''
            INSERT INTO trending_logs (
                region, query, traffic, action, anchor_title, anchor_url, match_count, error_message
            ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
        ''', region, query, traffic, action, anchor_title, anchor_url, match_count, error_message)
    except Exception as e:
        logger.error(f"[Trending-Logger] Failed to write to trending_logs: {e}")

async def update_trending_scores(db_pool, redis_client=None):
    """
    Orchestrates the trending score updates across all regions in parallel.
    """
    logger.info("Starting trending score update...")

    # Decay first: age out stale momentum before this run's fresh boosts land.
    # Stories still trending are re-boosted below and stay near the cap.
    await _decay_trend_scores(db_pool, redis_client)

    all_regions = ["US", "KE", "GB"]

    # Track traffic for normalization stats
    regional_traffic_stats = {} 
    
    # Recommendation 4: Local set to deduplicate ingestion within a single run
    processed_urls = set()
    
    async def process_region(region):
        async with db_pool.acquire() as conn:
            trends = await fetch_google_trends(region)
            if not trends:
                return
                
            logger.info(f"[{region}] Processing {len(trends)} trends")
            
            # Level 1 Normalization: Gather stats for this region
            traffics = [t['traffic'] for t in trends if t.get('traffic')]
            if traffics and redis_client:
                import statistics
                mean = statistics.mean(traffics)
                std = statistics.stdev(traffics) if len(traffics) > 1 else 0.0
                stats_payload = {
                    "mean": mean,
                    "std": std,
                    "max": max(traffics),
                    "updated_at": datetime.now(timezone.utc).isoformat()
                }
                try:
                    await redis_client.set(f"stats:v1:{region}:traffic", orjson.dumps(stats_payload), ex=86400)
                    logger.info(f"[{region}] Updated traffic stats in Redis: mean={mean:.2f}, std={std:.2f}")
                except Exception as e:
                    logger.warning(f"[{region}] Failed to save stats to Redis: {e}")

            # Recommendation 1: Parallelize embeddings for all trends in this region
            async def get_embedding(trend):
                # Combine query + all clean headlines for a much richer semantic search context
                search_text = f"{trend['query']} {trend['context_text']}"
                try:
                    return await embed_text(search_text)
                except Exception as e:
                    logger.error(f"[{region}] Embedding failed for '{trend['query']}': {e}")
                    return e

            tasks = [get_embedding(t) for t in trends]
            embeddings = await asyncio.gather(*tasks)
            
            for trend, embedding in zip(trends, embeddings):
                if isinstance(embedding, Exception):
                    continue
                
                # Deduplication within the run
                url = trend.get('anchor_url')
                if url and url in processed_urls:
                    logger.debug(f"[{region}] Skipping already processed URL: {url}")
                    continue
                if url:
                    processed_urls.add(url)

                try:
                    # Recommendation 3: Passing list directly for vector similarity.
                    # We cast the list (which asyncpg sends as float8[]) to ::vector.
                    matches = await conn.fetch("""
                        SELECT id, cluster_id, title, 1 - (embedding <=> $1::float8[]::vector) as similarity
                        FROM articles 
                        WHERE published_at > NOW() - INTERVAL '48 hours'
                        AND (embedding <=> $1::float8[]::vector) < 0.30
                        ORDER BY (embedding <=> $1::float8[]::vector) ASC
                        LIMIT 5
                    """, embedding)
                    
                    article_ids_to_boost = []
                    cluster_ids_to_boost = []

                    if matches:
                        cluster_ids_to_boost = {m['cluster_id'] for m in matches if m['cluster_id']}
                        article_ids_to_boost = {m['id'] for m in matches}
                        
                        max_sim = matches[0]['similarity']
                        logger.info(f"[{region}] Found {len(matches)} matches for '{trend['query']}' (Max similarity: {max_sim:.4f})")
                        
                        await log_trending_event(conn, region, trend['query'], "BOOSTED", 
                                                traffic=trend['traffic'], anchor_title=trend['anchor_title'], 
                                                anchor_url=trend['anchor_url'], match_count=len(matches))
                    else:
                        if trend['anchor_url']:
                            anchor_url_reason = is_junk_url(trend['anchor_url'], trend.get('anchor_title', ''), trend.get('query', ''))
                            if anchor_url_reason:
                                logger.info(f"[{region}] Skipping ingest for trend '{trend['query']}': {anchor_url_reason} ({trend['anchor_url']})")
                                await log_trending_event(
                                    conn,
                                    region,
                                    trend['query'],
                                    "SKIPPED",
                                    traffic=trend['traffic'],
                                    anchor_title=trend['anchor_title'],
                                    anchor_url=trend['anchor_url'],
                                    error_message=anchor_url_reason,
                                )
                                continue

                            logger.info(f"[{region}] Trend '{trend['query']}' not found. Ingesting: {trend['anchor_url']}")
                            await log_trending_event(conn, region, trend['query'], "INGEST_TRIGGERED", 
                                                    traffic=trend['traffic'], anchor_title=trend['anchor_title'], 
                                                    anchor_url=trend['anchor_url'])
                            
                            new_article_id = await ingest_from_url(trend['anchor_url'], db_pool, country_code=region)
                            if new_article_id:
                                article_ids_to_boost = [new_article_id]
                        else:
                            await log_trending_event(conn, region, trend['query'], "SKIPPED", 
                                                    traffic=trend['traffic'], error_message="No anchor URL available")

                    if article_ids_to_boost or cluster_ids_to_boost:
                        # Normalization Level 1 & 2
                        regional_max = traffics[0] if traffics else (trend['traffic'] or 1.0)
                        if redis_client:
                            try:
                                stats_json = await redis_client.get(f"stats:v1:{region}:traffic")
                                if stats_json:
                                    stats = orjson.loads(stats_json)
                                    regional_max = stats.get('max') or regional_max
                            except Exception:
                                pass
                        
                        # Use a scale of 0-10 for the trend boost, where 10 is the top trend in the region.
                        # This balances US (millions) with KE (thousands) perfectly.
                        trend_weight = 10.0 * (trend['traffic'] / regional_max)
                        
                        await conn.execute("""
                            UPDATE articles 
                            SET trend_score = LEAST(COALESCE(trend_score, 0) + $1, 12.0),
                                last_trend_update = NOW()
                            WHERE id = ANY($2::uuid[])
                            OR (cluster_id IS NOT NULL AND cluster_id = ANY($3::uuid[]))
                        """, trend_weight, list(article_ids_to_boost), list(cluster_ids_to_boost))
                        logger.info(f"[{region}] Boosted '{trend['query']}' with normalized weight {trend_weight:.2f}")

                except Exception as e:
                    logger.error(f"[{region}] Error processing trend '{trend.get('query')}': {e}")
                    try:
                        await log_trending_event(conn, region, trend.get('query', 'Unknown'), "ERROR", 
                                                 error_message=str(e))
                    except Exception:
                        pass

    # Process all regions in parallel
    await asyncio.gather(*[process_region(r) for r in all_regions])
    
    logger.info("Trending score update complete.")
