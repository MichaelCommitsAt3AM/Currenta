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

    print("🔌 Connecting to Supabase Postgres...")
    conn = await asyncpg.connect(db_url)
    try:
        print("✅ Connected!")
        
        # Check users count
        count = await conn.fetchval("SELECT count(*) FROM auth.users")
        print(f"👥 Total users in auth.users: {count}")
        
        # Get last 5 users
        users = await conn.fetch(
            "SELECT id, email, confirmed_at, created_at, last_sign_in_at FROM auth.users ORDER BY created_at DESC LIMIT 5"
        )
        print("\nLast 5 registered users:")
        for u in users:
            print(f"- ID: {u['id']}, Email: {u['email']}, Confirmed At: {u['confirmed_at']}, Created At: {u['created_at']}, Last Sign-in: {u['last_sign_in_at']}")

        # Query config settings from auth.config if available
        # Note: auth.config might not be accessible or might not exist depending on Supabase version
        try:
            config = await conn.fetch("SELECT * FROM auth.config LIMIT 5")
            print("\nAuth configuration:")
            for row in config:
                print(dict(row))
        except Exception as e:
            print(f"\nCould not fetch auth.config: {e}")

    except Exception as e:
        print(f"❌ Error: {e}")
    finally:
        await conn.close()

if __name__ == "__main__":
    asyncio.run(main())
