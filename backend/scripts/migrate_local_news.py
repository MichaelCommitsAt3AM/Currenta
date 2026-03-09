import asyncio
import asyncpg
import os
from dotenv import load_dotenv

# Load .env from the root
load_dotenv(os.path.join(os.path.dirname(__file__), "../../.env"))

async def migrate():
    database_url = os.environ.get("DATABASE_URL")
    if not database_url:
        print("DATABASE_URL not found in .env")
        return

    print(f"Connecting to {database_url}...")
    conn = await asyncpg.connect(database_url, ssl='require')

    try:
        print("Adding country_code column to articles...")
        # Added IF NOT EXISTS manually since ALTER TABLE ADD COLUMN doesn't support it directly in older PG
        # but modern ones do. Let's try column_exists check.
        await conn.execute('''
            DO $$ 
            BEGIN 
                IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                               WHERE table_name='articles' AND column_name='country_code') THEN
                    ALTER TABLE articles ADD COLUMN country_code VARCHAR(2);
                END IF;
            END $$;
        ''')

        print("Creating index on categories and country_code...")
        await conn.execute('''
            CREATE INDEX IF NOT EXISTS idx_articles_category_country 
            ON articles (country_code, categories);
        ''')

        print("Creating local_news_sync table...")
        await conn.execute('''
            CREATE TABLE IF NOT EXISTS local_news_sync (
                country_code VARCHAR(2) PRIMARY KEY,
                last_fetched_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
            );
        ''')

        print("Migration complete!")
    except Exception as e:
        print(f"Migration failed: {e}")
    finally:
        await conn.close()

if __name__ == "__main__":
    asyncio.run(migrate())
