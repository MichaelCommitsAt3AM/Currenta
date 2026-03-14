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
            title = item.title.text.strip()
            # Google Trends uses 'ht:approx_traffic' for search volume
            traffic_text = item.find('ht:approx_traffic').text if item.find('ht:approx_traffic') else "0"
            # Extract numeric value (e.g., "500,000+" -> 500000)
            traffic = int(re.sub(r'[^0-9]', '', traffic_text))
            
            # Google Trends uses 'ht:news_item' for the first related story
            news_item = item.find('ht:news_item')
            anchor_url = ""
            anchor_title = ""
            if news_item:
                anchor_title = news_item.find('ht:news_item_title').text if news_item.find('ht:news_item_title') else ""
                anchor_url = news_item.find('ht:news_item_url').text if news_item.find('ht:news_item_url') else ""

            trending_items.append({
                "query": title,
                "traffic": traffic,
                "anchor_title": anchor_title,
                "anchor_url": anchor_url,
                "region": region
            })
        except Exception as e:
            logger.warning(f"Error parsing trending item: {e}")
            continue
            
    # Filter out junk items from Google Trends
    filtered_items = []
    for item in trending_items:
        junk_reason = is_junk_content(item['anchor_title'], item['query'])
        if junk_reason:
            logger.info(f"Skipping junk trend '{item['query']}': {junk_reason}")
            continue
        filtered_items.append(item)
            
    return filtered_items

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
    Orchestrates the trending score updates across all regions.
    """
    logger.info("Starting trending score update...")
    
    all_regions = ["US", "KE"]
    for region in all_regions:
        trends = await fetch_google_trends(region)
        if not trends:
            continue
            
        logger.info(f"Processing {len(trends)} trends for {region}")
        
        for trend in trends:
            try:
                async with db_pool.acquire() as conn:
                    # 1. Semantic Search: Check if we have a match in the last 48 hours
                    # We use the trend query and anchor title for embedding
                    search_text = f"{trend['query']} {trend['anchor_title']}"
                    embedding = await embed_text(search_text)
                    embedding_str = f"[{','.join(map(str, embedding))}]"
                    
                    # Find semantic matches (>0.70 similarity) within last 48 hours
                    # We've lowered the threshold to 0.70 to be more inclusive of related news.
                    matches = await conn.fetch("""
                        SELECT id, cluster_id, title, 1 - (embedding <=> $1::vector) as similarity
                        FROM articles 
                        WHERE published_at > NOW() - INTERVAL '48 hours'
                        AND 1 - (embedding <=> $1::vector) > 0.70
                        ORDER BY 1 - (embedding <=> $1::vector) DESC
                        LIMIT 5
                    """, embedding_str)
                    
                    article_ids_to_boost = []
                    cluster_ids_to_boost = []

                    if matches:
                        # Found existing matches!
                        cluster_ids_to_boost = {m['cluster_id'] for m in matches if m['cluster_id']}
                        article_ids_to_boost = {m['id'] for m in matches}
                        
                        max_sim = matches[0]['similarity']
                        logger.info(f"Found {len(matches)} matches for trend '{trend['query']}' (Max similarity: {max_sim:.4f})")
                        
                        await log_trending_event(conn, region, trend['query'], "BOOSTED", 
                                                traffic=trend['traffic'], anchor_title=trend['anchor_title'], 
                                                anchor_url=trend['anchor_url'], match_count=len(matches))
                    else:
                        # No match found: Trigger on-demand ingest if we have an anchor URL
                        if trend['anchor_url']:
                            logger.info(f"Trend '{trend['query']}' not found in DB. Ingesting: {trend['anchor_url']}")
                            await log_trending_event(conn, region, trend['query'], "INGEST_TRIGGERED", 
                                                    traffic=trend['traffic'], anchor_title=trend['anchor_title'], 
                                                    anchor_url=trend['anchor_url'])
                            
                            # ingest_from_url now returns the newly created (or existing) article UUID
                            new_article_id = await ingest_from_url(trend['anchor_url'], db_pool, country_code=region)
                            if new_article_id:
                                article_ids_to_boost = [new_article_id]
                                logger.info(f"Successfully ingested and prepared to boost new article {new_article_id}")
                        else:
                            await log_trending_event(conn, region, trend['query'], "SKIPPED", 
                                                    traffic=trend['traffic'], error_message="No anchor URL available")

                    # Apply boost if we have anything to boost
                    if article_ids_to_boost or cluster_ids_to_boost:
                        import math
                        trend_weight = math.log(trend['traffic'] + 1)
                        
                        # Use COALESCE to handle potential NULLs in trend_score
                        await conn.execute("""
                            UPDATE articles 
                            SET trend_score = COALESCE(trend_score, 0) + $1,
                                last_trend_update = NOW()
                            WHERE id = ANY($2::uuid[])
                            OR (cluster_id IS NOT NULL AND cluster_id = ANY($3::uuid[]))
                        """, trend_weight, list(article_ids_to_boost), list(cluster_ids_to_boost))
                        logger.info(f"Boosted trend '{trend['query']}' with weight {trend_weight:.2f}")

            except Exception as e:
                logger.error(f"Error processing trend '{trend.get('query')}': {e}")
                try:
                    async with db_pool.acquire() as conn:
                        await log_trending_event(conn, region, trend.get('query', 'Unknown'), "ERROR", 
                                                error_message=str(e))
                except Exception:
                    pass
                
    logger.info("Trending score update complete.")
