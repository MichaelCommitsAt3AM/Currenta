import asyncio
import os
import asyncpg
from dotenv import load_dotenv

load_dotenv()

async def check_logs():
    database_url = os.environ.get("DATABASE_URL")
    if not database_url:
        print("DATABASE_URL not set")
        return

    conn = await asyncpg.connect(dsn=database_url, ssl='require', statement_cache_size=0)
    try:
        rows = await conn.fetch("SELECT * FROM trending_logs ORDER BY created_at DESC LIMIT 10")
        if not rows:
            print("No trending logs found.")
        else:
            for r in rows:
                print(f"[{r['created_at']}] {r['region']} - {r['query']} - {r['action']} - {r['error_message']}")
    finally:
        await conn.close()

if __name__ == "__main__":
    asyncio.run(check_logs())
