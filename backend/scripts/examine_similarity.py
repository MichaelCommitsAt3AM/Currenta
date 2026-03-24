import asyncio
import os
import asyncpg
import httpx
from dotenv import load_dotenv
from backend.services.trending import fetch_google_trends
from backend.services.ingestion import embed_text

load_dotenv()

async def test_similarity():
    database_url = os.environ.get("DATABASE_URL")
    print("Fetching trends...")
    trends = await fetch_google_trends("US")
    if not trends:
        print("No trends found.")
        return
    
    conn = await asyncpg.connect(dsn=database_url, ssl='require', statement_cache_size=0)
    try:
        for trend in trends[:3]:
            query = trend['query']
            anchor = trend['anchor_title']
            search_text = f"{query} {anchor}"
            print(f"\nTrend: {query}")
            print(f"Search text: {search_text}")
            
            embedding = await embed_text(search_text)
            embedding_str = f"[{','.join(map(str, embedding))}]"
            
            # Find best match in DB
            best_match = await conn.fetchrow("""
                SELECT title, 1 - (embedding <=> $1::vector) as similarity
                FROM articles 
                WHERE published_at > NOW() - INTERVAL '72 hours'
                ORDER BY embedding <=> $1::vector ASC
                LIMIT 1
            """, embedding_str)
            
            if best_match:
                print(f"Best match: {best_match['title']}")
                print(f"Similarity: {best_match['similarity']:.4f}")
            else:
                print("No recent articles found in DB.")
                
    finally:
        await conn.close()

if __name__ == "__main__":
    asyncio.run(test_similarity())
