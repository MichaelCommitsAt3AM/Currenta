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
        print("Creating user_profiles table...")
        await conn.execute('''
            CREATE TABLE IF NOT EXISTS user_profiles (
                user_id UUID PRIMARY KEY,
                preferred_country VARCHAR(2),
                created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
                updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
            );
        ''')

        print("Migration complete!")
    except Exception as e:
        print(f"Migration failed: {e}")
    finally:
        await conn.close()

if __name__ == "__main__":
    asyncio.run(migrate())
