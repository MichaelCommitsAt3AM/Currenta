import asyncio
import os
import sys
import asyncpg
from dotenv import load_dotenv

load_dotenv()

async def apply_migration():
    if len(sys.argv) < 2:
        print("Usage: python3 apply_migration.py <path_to_sql_file>")
        return

    database_url = os.environ.get("DATABASE_URL")
    if not database_url:
        print("DATABASE_URL not set")
        return

    migration_path = sys.argv[1]
    if not os.path.exists(migration_path):
        print(f"Migration file not found: {migration_path}")
        return

    with open(migration_path, "r") as f:
        sql = f.read()

    # Hosted Supabase's pooler requires SSL; the self-hosted stack's `db`
    # container has none configured over the private docker network and
    # actively rejects the upgrade — same DB_SSL_MODE switch as
    # backend/core/db.py's init_db_pool().
    ssl_mode = os.environ.get("DB_SSL_MODE", "require")
    ssl_param = False if ssl_mode == "disable" else ssl_mode

    print(f"Applying migration from {migration_path}...")
    try:
        conn = await asyncpg.connect(dsn=database_url, ssl=ssl_param)
        await conn.execute(sql)
        await conn.close()
        print("Migration applied successfully.")
    except Exception as e:
        print(f"Failed to apply migration: {e}")

if __name__ == "__main__":
    asyncio.run(apply_migration())
