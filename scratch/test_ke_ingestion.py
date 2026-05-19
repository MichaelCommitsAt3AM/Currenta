import asyncio
import os
import sys
import logging

# Ensure backend can be imported
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))

# Set up logging to stdout
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s | %(levelname)s | %(name)s | %(message)s'
)

from backend.core.db import init_db_pool, close_connections
from backend.services.trending import fetch_google_trends
from backend.services.ingestion import ingest_from_url

async def main():
    print("Initializing database pool...")
    db_pool = await init_db_pool()
    if not db_pool:
        print("Failed to initialize database pool.")
        return

    try:
        print("Fetching Google Trends for Kenya ('KE')...")
        trends = await fetch_google_trends('KE')
        if not trends:
            print("No trends found or failed to fetch trends.")
            return

        print(f"Found {len(trends)} trends. Processing ingestion for each...")
        for idx, trend in enumerate(trends, 1):
            query = trend.get('query')
            url = trend.get('anchor_url')
            title = trend.get('anchor_title')
            print("\n" + "="*80)
            print(f"[{idx}/{len(trends)}] TREND: '{query}'")
            print(f"  Anchor Title: {title}")
            print(f"  Anchor URL:   {url}")
            
            if not url:
                print("  ❌ Skipping: No anchor URL available.")
                continue
                
            print(f"  Triggering ingestion for: {url} with country_code='KE'...")
            
            # We call ingest_from_url
            try:
                article_id = await ingest_from_url(url, db_pool, country_code='KE')
                if article_id:
                    print(f"  ✅ SUCCESS: Ingested article ID: {article_id}")
                else:
                    print("  ❌ INGESTION RETURNED NONE (Skipped or Failed)")
                    
                    # Query ingestion_logs to get the exact reason
                    async with db_pool.acquire() as conn:
                        log = await conn.fetchrow(
                            "SELECT status, error_type, error_message FROM ingestion_logs WHERE original_url = $1 ORDER BY created_at DESC LIMIT 1",
                            url
                        )
                        if log:
                            print(f"  📋 Ingestion Log: Status={log['status']} | ErrorType={log['error_type']} | Message={log['error_message']}")
                        else:
                            print("  📋 No recent ingestion log found in database.")
            except Exception as e:
                print(f"  ❌ Error during ingestion call: {e}")
                
    finally:
        print("\nClosing connections...")
        await close_connections()

if __name__ == '__main__':
    asyncio.run(main())
