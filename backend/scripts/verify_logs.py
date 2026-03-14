import asyncio
import os
import asyncpg
from dotenv import load_dotenv

load_dotenv()

async def check_logs():
    database_url = os.environ.get("DATABASE_URL")
    print("Connecting...")
    conn = await asyncpg.connect(dsn=database_url, ssl='require')
    
    print("\n--- Last 5 Trending Logs ---")
    rows = await conn.fetch("SELECT created_at, query, action, match_count FROM trending_logs ORDER BY created_at DESC LIMIT 5")
    for r in rows:
        print(f"[{r['created_at']}] {r['query']} -> {r['action']} (Matches: {r['match_count']})")
        
    print("\n--- Last 5 Ingestion Logs (Inferred Trending) ---")
    i_rows = await conn.fetch("SELECT created_at, original_url, status, error_type FROM ingestion_logs ORDER BY created_at DESC LIMIT 5")
    for r in i_rows:
        print(f"[{r['created_at']}] {r['status']} | {r['error_type']} | {r['original_url'][:50]}...")
        
    await conn.close()

if __name__ == "__main__":
    asyncio.run(check_logs())
