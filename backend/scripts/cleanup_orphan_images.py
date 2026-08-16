"""Delete cover images in the `article-images` bucket that no article references.

Orphans accumulated because processFeed used to upload the scraped cover image
*before* the article ran the junk/LLM/dedup gauntlet, so every discarded article
left its JPEG behind. The ingestion ordering is fixed, but the existing orphans
still have to be swept up.

Objects must be removed through the Storage API — deleting rows from
`storage.objects` only drops the metadata and leaves the bytes (and the quota
usage) in place.

Usage:
    python -m backend.scripts.cleanup_orphan_images              # dry run
    python -m backend.scripts.cleanup_orphan_images --apply
    python -m backend.scripts.cleanup_orphan_images --apply --min-age-days 3
"""

import argparse
import asyncio
import os

import asyncpg
from dotenv import load_dotenv
from supabase import create_client

load_dotenv()

BUCKET = "article-images"

# Objects younger than this are never touched: an in-flight ingestion run uploads
# the image moments before inserting the article row, and we must not delete an
# image out from under a article that is about to reference it.
DEFAULT_MIN_AGE_DAYS = 1

# Supabase's storage remove() accepts a list of paths; keep batches modest so a
# failure costs little and the request stays well inside limits.
BATCH_SIZE = 100

# `image_url` is a full public URL; the object name is everything after the
# bucket segment, minus any query string the SDK may have appended.
ORPHAN_QUERY = """
WITH referenced AS (
    SELECT DISTINCT split_part(split_part(image_url, '/article-images/', 2), '?', 1) AS obj
    FROM articles
    WHERE image_url LIKE '%/article-images/%'
)
SELECT o.name, (o.metadata->>'size')::bigint AS bytes, o.created_at
FROM storage.objects o
WHERE o.bucket_id = $1
  AND o.created_at < now() - ($2 || ' days')::interval
  AND NOT EXISTS (SELECT 1 FROM referenced r WHERE r.obj = o.name)
ORDER BY o.created_at
"""

# Re-checked immediately before each delete batch, so an article inserted while
# this script was running still protects its image.
STILL_ORPHAN_QUERY = """
SELECT o.name
FROM storage.objects o
WHERE o.bucket_id = $1
  AND o.name = ANY($2::text[])
  AND NOT EXISTS (
      SELECT 1 FROM articles a
      WHERE a.image_url LIKE '%/article-images/%'
        AND split_part(split_part(a.image_url, '/article-images/', 2), '?', 1) = o.name
  )
"""


def human(num_bytes: int) -> str:
    size = float(num_bytes or 0)
    for unit in ("B", "KB", "MB", "GB"):
        if abs(size) < 1024:
            return f"{size:.1f} {unit}"
        size /= 1024
    return f"{size:.1f} TB"


async def main() -> None:
    parser = argparse.ArgumentParser(description="Delete orphaned article cover images.")
    parser.add_argument("--apply", action="store_true",
                        help="Actually delete. Without this the script only reports.")
    parser.add_argument("--min-age-days", type=int, default=DEFAULT_MIN_AGE_DAYS,
                        help=f"Skip objects newer than this (default: {DEFAULT_MIN_AGE_DAYS}).")
    parser.add_argument("--limit", type=int, default=None,
                        help="Delete at most this many objects.")
    args = parser.parse_args()

    database_url = os.environ.get("DATABASE_URL")
    supabase_url = os.environ.get("SUPABASE_URL")
    service_key = os.environ.get("SUPABASE_SERVICE_ROLE_KEY")

    missing = [name for name, value in (
        ("DATABASE_URL", database_url),
        ("SUPABASE_URL", supabase_url),
        ("SUPABASE_SERVICE_ROLE_KEY", service_key),
    ) if not value]
    if missing:
        print(f"Error: missing environment variables: {', '.join(missing)}")
        return

    conn = await asyncpg.connect(dsn=database_url, statement_cache_size=0)
    try:
        total_objects, total_bytes = await conn.fetchrow(
            "SELECT count(*), coalesce(sum((metadata->>'size')::bigint), 0) "
            "FROM storage.objects WHERE bucket_id = $1",
            BUCKET,
        )
        print(f"Bucket '{BUCKET}': {total_objects} objects, {human(total_bytes)}")

        orphans = await conn.fetch(ORPHAN_QUERY, BUCKET, str(args.min_age_days))
        if args.limit:
            orphans = orphans[: args.limit]

        orphan_bytes = sum(row["bytes"] or 0 for row in orphans)
        print(f"Orphans older than {args.min_age_days}d: {len(orphans)} objects, {human(orphan_bytes)}")

        if not orphans:
            print("Nothing to do.")
            return

        print(f"Oldest: {orphans[0]['created_at']}   Newest: {orphans[-1]['created_at']}")

        if not args.apply:
            print("\nDry run — no objects deleted. Re-run with --apply to delete.")
            print("Sample of what would be removed:")
            for row in orphans[:10]:
                print(f"  {human(row['bytes']):>9}  {row['name']}  {row['created_at']}")
            return

        storage = create_client(supabase_url, service_key).storage.from_(BUCKET)
        deleted = 0
        freed = 0
        skipped = 0
        failed = 0
        sizes = {row["name"]: row["bytes"] or 0 for row in orphans}
        names = list(sizes)

        for start in range(0, len(names), BATCH_SIZE):
            batch = names[start : start + BATCH_SIZE]

            # An article may have claimed one of these images since we built the list.
            confirmed = [r["name"] for r in await conn.fetch(STILL_ORPHAN_QUERY, BUCKET, batch)]
            skipped += len(batch) - len(confirmed)
            if not confirmed:
                continue

            try:
                await asyncio.to_thread(storage.remove, confirmed)
            except Exception as exc:
                failed += len(confirmed)
                print(f"  batch at offset {start} failed: {type(exc).__name__} - {exc}")
                continue

            deleted += len(confirmed)
            freed += sum(sizes[name] for name in confirmed)
            print(f"  deleted {deleted}/{len(names)} ({human(freed)} freed)")

        print(f"\nDone. Deleted {deleted} objects, freed {human(freed)}.")
        if skipped:
            print(f"Skipped {skipped} objects that gained an article reference mid-run.")
        if failed:
            print(f"Failed to delete {failed} objects — re-run to retry.")

        remaining_objects, remaining_bytes = await conn.fetchrow(
            "SELECT count(*), coalesce(sum((metadata->>'size')::bigint), 0) "
            "FROM storage.objects WHERE bucket_id = $1",
            BUCKET,
        )
        print(f"Bucket now: {remaining_objects} objects, {human(remaining_bytes)}")
    finally:
        await conn.close()


if __name__ == "__main__":
    asyncio.run(main())
