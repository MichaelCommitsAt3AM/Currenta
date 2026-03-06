import os
import asyncio
import asyncpg
from dotenv import load_dotenv

# Load environment variables
load_dotenv()

async def delete_news_updates():
    database_url = os.environ.get("DATABASE_URL")
    if not database_url:
        print("Error: DATABASE_URL not set in environment.")
        return

    try:
        print("Connecting to PostgreSQL...")
        conn = await asyncpg.connect(dsn=database_url, ssl='require')
        
        # Count target articles
        count = await conn.fetchval("SELECT count(*) FROM articles WHERE LOWER(TRIM(title)) = 'news update'")
        print(f"Found {count} articles with title 'News Update'.")

        if count > 0:
            # Delete target articles
            # We can also be more selective if needed, but the user specifically mentioned 'News Update'
            # whose content is usually incomplete/inaccurate.
            res = await conn.execute("DELETE FROM articles WHERE LOWER(TRIM(title)) = 'news update'")
            print(f"Successfully deleted: {res}")
        else:
            print("No articles to delete.")

        await conn.close()
        print("Database connection closed.")

    except Exception as e:
        print(f"Error during article deletion: {e}")

if __name__ == "__main__":
    asyncio.run(delete_news_updates())
