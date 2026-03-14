import asyncio
import os
import logging
from dotenv import load_dotenv
import asyncpg
from backend.services.trending import fetch_google_trends, update_trending_scores

load_dotenv()

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

async def test_trending():
    database_url = os.environ.get("DATABASE_URL")
    if not database_url:
        logger.error("DATABASE_URL not set")
        return

    logger.info("Fetching trends for US...")
    trends = await fetch_google_trends("US")
    for t in trends[:5]:
        logger.info(f"Trend: {t['query']} ({t['traffic']}+ searches)")
        if t['anchor_url']:
            logger.info(f"  Anchor: {t['anchor_title']} - {t['anchor_url']}")

    logger.info("\nConnecting to database to test score updates...")
    try:
        pool = await asyncpg.create_pool(
            dsn=database_url,
            ssl='require',
            statement_cache_size=0,
            min_size=1,
            max_size=2,
        )
        
        # Test update_trending_scores (limiting to US for quick test if needed, 
        # but the function does all regions. We can just call it.)
        await update_trending_scores(pool)
        
        # Verify changes
        async with pool.acquire() as conn:
            top_trending = await conn.fetch("""
                SELECT id, title, trend_score, last_trend_update 
                FROM articles 
                WHERE trend_score > 0 
                ORDER BY trend_score DESC 
                LIMIT 5
            """)
            
            if top_trending:
                logger.info("\nTop Trending Articles in DB:")
                for r in top_trending:
                    logger.info(f"  [{r['trend_score']:.2f}] {r['title']}")
            else:
                logger.info("\nNo articles boosted yet (might need existing similar articles in DB).")
                
        await pool.close()
    except Exception as e:
        logger.error(f"Database test failed: {e}")

if __name__ == "__main__":
    asyncio.run(test_trending())
