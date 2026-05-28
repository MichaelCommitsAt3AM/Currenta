import asyncio
import os
import sys
from dotenv import load_dotenv
import asyncpg

sys.path.append(os.path.join(os.path.dirname(__file__), ".."))
load_dotenv()

async def main():
    db_url = os.getenv("DATABASE_URL")
    if not db_url:
        print("❌ DATABASE_URL is not set in .env")
        return

    print("🔌 Connecting to Supabase Postgres...")
    # statement_cache_size=0 is required for PgBouncer transaction mode
    conn = await asyncpg.connect(db_url, statement_cache_size=0)
    try:
        print("✅ Connected!")
        
        # 1. Total articles
        total_articles = await conn.fetchval("SELECT count(*) FROM articles")
        print(f"\n📊 Total articles: {total_articles}")
        
        # 2. Total trending articles (trend_score > 0)
        total_trending = await conn.fetchval("SELECT count(*) FROM articles WHERE trend_score > 0")
        print(f"🔥 Total articles with trend_score > 0: {total_trending}")
        
        # 3. Trending articles grouped by country_code
        groups = await conn.fetch(
            "SELECT country_code, count(*) FROM articles WHERE trend_score > 0 GROUP BY country_code"
        )
        print("\nTrending articles by country_code:")
        for g in groups:
            print(f"- {g['country_code']}: {g['count']}")
            
        # 4. Details of trending articles
        details = await conn.fetch(
            "SELECT id, title, country_code, trend_score, published_at FROM articles WHERE trend_score > 0 ORDER BY trend_score DESC LIMIT 10"
        )
        print("\nTop trending articles:")
        for d in details:
            print(f"- ID: {d['id']}, Title: {d['title'][:40]}, Country: {d['country_code']}, Score: {d['trend_score']}, Published: {d['published_at']}")

    except Exception as e:
        print(f"❌ Error: {e}")
    finally:
        await conn.close()

if __name__ == "__main__":
    asyncio.run(main())
