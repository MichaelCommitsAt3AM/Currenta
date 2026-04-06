import asyncio
import os
import asyncpg
from dotenv import load_dotenv
from datetime import datetime

# Load environment variables (handles both root and backend directory .env)
load_dotenv()
if not os.environ.get("DATABASE_URL"):
    load_dotenv("../.env")

async def audit_duplicates():
    database_url = os.environ.get("DATABASE_URL")
    if not database_url:
        print("Error: DATABASE_URL not found in environment.")
        return

    print("Connecting to Supabase...")
    try:
        # We set statement_cache_size=0 because Supabase uses PgBouncer which 
        # doesn't support prepared statements in transaction mode.
        conn = await asyncpg.connect(dsn=database_url, ssl='require', statement_cache_size=0)
    except Exception as e:
        print(f"Failed to connect: {e}")
        return

    print("Fetching semantic duplicate skip logs...\n")
    
    # Query logs joined with articles to see winners vs losers
    query = """
        SELECT 
            l.created_at,
            l.original_url AS skipped_url,
            a.title AS winner_title,
            a.original_url AS winner_url,
            l.semantic_similarity,
            l.similarity_threshold,
            l.matched_article_id,
            l.content_preview AS skipped_preview
        FROM ingestion_logs l
        LEFT JOIN articles a ON l.matched_article_id = a.id
        WHERE l.error_type = 'DUPLICATE_EMBEDDING'
        ORDER BY l.created_at DESC
        LIMIT 50
    """
    
    try:
        rows = await conn.fetch(query)
        
        if not rows:
            print("No semantic duplicate logs found.")
        else:
            print(f"{'TIMESTAMP':<20} | {'SIM':<5} | {'EVENT DETAILS'}")
            print("-" * 100)
            
            for r in rows:
                ts = r['created_at'].strftime("%Y-%m-%d %H:%M")
                sim = f"{r['semantic_similarity']:.3f}" if r['semantic_similarity'] else "N/A"
                print(f"{ts:<20} | {sim:<5} | REJECTED: {r['skipped_url'][:60]}")
                if r['winner_title']:
                    print(f"{' ' * 28} | MATCHED WITH: \"{r['winner_title'][:60]}\"")
                    print(f"{' ' * 28} | WINNER URL:   {r['winner_url'][:60]}")
                else:
                    print(f"{' ' * 28} | MATCHED ID:   {r['matched_article_id']} (Article may have been deleted)")
                
                if r['skipped_preview']:
                    print(f"{' ' * 28} | OLD PREVIEW:  {r['skipped_preview'][:100]}...")
                
                print("-" * 100)
                
        # Also summary stats
        stats = await conn.fetchrow("""
            SELECT 
                COUNT(*) as total,
                AVG(semantic_similarity) as avg_sim,
                MAX(semantic_similarity) as max_sim
            FROM ingestion_logs 
            WHERE error_type = 'DUPLICATE_EMBEDDING'
        """)
        
        if stats and stats['total'] > 0:
            print(f"\nSummary: {stats['total']} semantic duplicates found.")
            print(f"Average Similarity: {stats['avg_sim']:.4f}")
            print(f"Max Similarity Found: {stats['max_sim']:.4f}")

    except Exception as e:
        print(f"Query error: {e}")
    finally:
        await conn.close()

if __name__ == "__main__":
    asyncio.run(audit_duplicates())
