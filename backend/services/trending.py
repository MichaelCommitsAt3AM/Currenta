import logging
import asyncio
import httpx
import re
from bs4 import BeautifulSoup
from datetime import datetime, timezone
from typing import List, Dict, Optional
from .ingestion import embed_text, ingest_from_url, is_junk_content

logger = logging.getLogger(__name__)

# Google Trends RSS URLs
TRENDS_RSS_URLS = {
    "US": "https://trends.google.com/trending/rss?geo=US",
    "KE": "https://trends.google.com/trending/rss?geo=KE",
}

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

async def update_trending_scores(db_pool):
    """
    Orchestrates the trending score updates across all regions in parallel.
    """
    logger.info("Starting trending score update...")
    all_regions = ["US", "KE"]
    
    # Recommendation 4: Local set to deduplicate ingestion within a single run
    processed_urls = set()
    
    async def process_region(region):
        async with db_pool.acquire() as conn:
            trends = await fetch_google_trends(region)
            if not trends:
                return
                
            logger.info(f"[{region}] Processing {len(trends)} trends")
            
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
                        AND 1 - (embedding <=> $1::float8[]::vector) > 0.70
                        ORDER BY 1 - (embedding <=> $1::float8[]::vector) DESC
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
                        import math
                        trend_weight = math.log(trend['traffic'] + 1)
                        
                        await conn.execute("""
                            UPDATE articles 
                            SET trend_score = COALESCE(trend_score, 0) + $1,
                                last_trend_update = NOW(),
                                ranking_score = ((1.0 + (COALESCE(trend_score, 0) + $1)) * exp(-0.05 * extract(epoch from (now() - published_at))/3600))
                            WHERE id = ANY($2::uuid[])
                            OR (cluster_id IS NOT NULL AND cluster_id = ANY($3::uuid[]))
                        """, trend_weight, list(article_ids_to_boost), list(cluster_ids_to_boost))
                        logger.info(f"[{region}] Boosted '{trend['query']}' with weight {trend_weight:.2f} and updated ranking score")

                except Exception as e:
                    logger.error(f"[{region}] Error processing trend '{trend.get('query')}': {e}")
                    try:
                        await log_trending_event(conn, region, trend.get('query', 'Unknown'), "ERROR", 
                                                error_message=str(e))
                    except Exception:
                        pass

    # Process all regions in parallel
    await asyncio.gather(*[process_region(r) for r in all_regions])
    
    # Finally, refresh ranking scores for all recent articles to account for time decay
    # even if they weren't boosted this run.
    async with db_pool.acquire() as conn:
        try:
            logger.info("Refreshing ranking scores for all articles from last 7 days...")
            await conn.execute("""
                UPDATE articles 
                SET ranking_score = ((1.0 + trend_score) * exp(-0.05 * extract(epoch from (now() - published_at))/3600))
                WHERE published_at > NOW() - INTERVAL '7 days'
            """)
        except Exception as e:
            logger.error(f"Failed to refresh ranking scores: {e}")

    logger.info("Trending score update complete.")
