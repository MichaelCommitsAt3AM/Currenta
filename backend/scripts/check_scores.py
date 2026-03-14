import asyncio
import os
import asyncpg
from dotenv import load_dotenv

load_dotenv()

async def check():
    database_url = os.environ.get("DATABASE_URL")
    if not database_url:
        print("DATABASE_URL not set")
        return

    try:
        conn = await asyncpg.connect(dsn=database_url, ssl='require', statement_cache_size=0)
        
        # Check for NULLs vs 0s
        null_count = await conn.fetchval("SELECT count(*) FROM articles WHERE trend_score IS NULL")
        zero_count = await conn.fetchval("SELECT count(*) FROM articles WHERE trend_score = 0")
        pos_count = await conn.fetchval("SELECT count(*) FROM articles WHERE trend_score > 0")
        
        print(f"NULLs: {null_count}")
        print(f"Zeros: {zero_count}")
        print(f"Positive: {pos_count}")
        
        if null_count > 0:
            print("Found NULL trend_scores! This will break 'trend_score + weight' updates.")
            
        await conn.close()
    except Exception as e:
        print(f"Error: {e}")

if __name__ == "__main__":
    asyncio.run(check())
