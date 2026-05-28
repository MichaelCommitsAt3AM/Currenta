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

    # Disable prepared statements cache to avoid issues with PgBouncer
    conn = await asyncpg.connect(db_url, statement_cache_size=0)
    try:
        articles = await conn.fetch(
            "SELECT id, title, source_name, published_at, trend_score, ranking_score "
            "FROM articles WHERE ranking_score > 0 ORDER BY ranking_score DESC"
        )
        
        # Write all records to a markdown file
        md_path = "high_ranking_articles.md"
        with open(md_path, "w", encoding="utf-8") as f:
            f.write("# Articles with Ranking Score > 0\n\n")
            f.write(f"Total Count: **{len(articles)}**\n\n")
            f.write("| # | Title | Source | Published At | Trend Score | Ranking Score | ID |\n")
            f.write("|---|---|---|---|---|---|---|\n")
            for idx, art in enumerate(articles, start=1):
                title = art['title'].replace('|', '\\|')
                f.write(f"| {idx} | {title} | {art['source_name']} | {art['published_at']} | {art['trend_score']:.2f} | {art['ranking_score']:.4f} | `{art['id']}` |\n")
        
        print(f"✅ Successfully wrote {len(articles)} articles to {md_path}")
        
        # Print top 15 for console output
        print("\nTop 15 Articles:")
        for idx, art in enumerate(articles[:15], start=1):
            print(f"{idx:02d}. [Rank Score: {art['ranking_score']:.4f} | Trend Score: {art['trend_score']:.2f}] {art['title']} ({art['source_name']})")
            
    except Exception as e:
        print(f"❌ Error: {e}")
    finally:
        await conn.close()

if __name__ == "__main__":
    asyncio.run(main())
