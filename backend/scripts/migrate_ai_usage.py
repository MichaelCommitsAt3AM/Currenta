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

    print(f"Connecting to database...")
    conn = await asyncpg.connect(database_url, ssl='require')

    try:
        print("Creating user_ai_usage table...")
        await conn.execute('''
            CREATE TABLE IF NOT EXISTS user_ai_usage (
                user_id UUID PRIMARY KEY,
                daily_count INTEGER DEFAULT 0,
                last_reset_at DATE DEFAULT CURRENT_DATE
            );
        ''')
        
        print("Migration complete!")
    except Exception as e:
        print(f"Migration failed: {e}")
    finally:
        await conn.close()

if __name__ == "__main__":
    asyncio.run(migrate())
