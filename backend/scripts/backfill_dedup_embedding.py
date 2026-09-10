"""
One-off backfill: populate `articles.event_key` / `articles.dedup_embedding`
for recently-published articles so semantic dedup (find_cluster_match) has a
signal to compare against immediately after the event-key change ships.

Context: find_cluster_match now compares `dedup_embedding` = embed(event_key)
instead of embed(title + summary). event_key is a framing-free "who did what
where" line the summarizer LLM emits going forward — see
supabase/migrations/20260910073500_add_dedup_embedding.sql.

Scope is deliberately tiny: find_cluster_match only looks back
DUPLICATE_LOOKBACK_DAYS (7), so only articles published in roughly the last
week ever act as match targets. Everything older stays NULL by design (the
find_cluster_match query filters `dedup_embedding IS NOT NULL`). Default
window here is 10 days for a small safety margin.

The original scraped article text is not stored, so event_key for historical
rows is regenerated from the stored title + summary (enough for a dedup key).

Run from the repo root, inside the `api` or `worker` container (needs
DATABASE_URL / DB_SSL_MODE, GEMINI_API_KEY and an embedding provider
configured the same way ingestion.py does):

    python -m backend.scripts.backfill_dedup_embedding            # dry run
    python -m backend.scripts.backfill_dedup_embedding --commit   # writes
    python -m backend.scripts.backfill_dedup_embedding --days 14 --commit

Writes its report/cache to /tmp, not the repo root — CLAUDE.md: `api`/`worker`
run `uvicorn --reload` over the mounted repo, so a file under the repo root
triggers a spurious restart mid-run.
"""
import argparse
import asyncio
import json
import os

import asyncpg
from dotenv import load_dotenv

from backend.services import ingestion
from backend.services.ingestion import embed_texts, parse_llm_response

load_dotenv()

REPORT_PATH = "/tmp/backfill_dedup_embedding_report.txt"
CACHE_PATH = "/tmp/backfill_dedup_embedding_cache.json"  # article id -> {event_key, dedup_embedding}

EVENT_KEY_PROMPT = (
    "You are given the headline and summary of a news article. Return a raw JSON "
    'object: {"event_key": "...", "key_entities": ["..."]}.\n'
    '"event_key" MUST be ONE sentence stating WHO did WHAT, WHERE, and the core '
    "OUTCOME, naming the primary entities explicitly. It is used to detect that "
    "two articles cover the SAME event, so include ONLY core facts — no analysis, "
    "no consequences, no background, and none of this article's particular angle. "
    "Two articles about the same event must produce almost the same event_key.\n"
    '"key_entities": up to 6 of the most important proper nouns (people, orgs, '
    "places, products), shortest recognizable form.\n\n"
    "Headline: {title}\nSummary: {summary}"
)


def _load_cache() -> dict:
    if os.path.exists(CACHE_PATH):
        with open(CACHE_PATH) as f:
            return json.load(f)
    return {}


def _save_cache(cache: dict) -> None:
    with open(CACHE_PATH, "w") as f:
        json.dump(cache, f)


async def _get_connection() -> asyncpg.Connection:
    database_url = os.environ["DATABASE_URL"]
    ssl_mode = os.environ.get("DB_SSL_MODE", "require")
    ssl_param = False if ssl_mode == "disable" else ssl_mode
    return await asyncpg.connect(dsn=database_url, ssl=ssl_param)


async def _generate_event_key(title: str, summary: str) -> tuple[str, list[str]]:
    """Reuses ingestion's Gemini client. Falls back to the title on any failure
    so a row is never left without a usable dedup key."""
    client = ingestion._gemini_client or ingestion._vertex_client
    if not client:
        return title, []
    from google.genai import types as genai_types

    prompt = EVENT_KEY_PROMPT.format(title=title, summary=summary)
    try:
        resp = await client.aio.models.generate_content(
            model="gemini-2.5-flash-lite",
            contents=prompt,
            config=genai_types.GenerateContentConfig(
                temperature=0.1, response_mime_type="application/json"
            ),
        )
        # parse_llm_response tolerates the extra/missing fields and applies the
        # same event_key/title fallback the live path uses.
        parsed = parse_llm_response(resp.text)
        return parsed["event_key"], parsed.get("key_entities", [])
    except Exception as e:  # noqa: BLE001
        print(f"  [WARN] event_key generation failed for {title!r}: {e}")
        return title, []


async def run(commit: bool, days: int) -> None:
    cache = _load_cache()
    conn = await _get_connection()
    try:
        rows = await conn.fetch(
            """
            SELECT id, title, summary
            FROM articles
            WHERE dedup_embedding IS NULL
              AND published_at > now() - make_interval(days => $1::int)
            ORDER BY published_at
            """,
            days,
        )
        print(f"{len(rows)} article(s) in the last {days} days need dedup_embedding.")

        to_process = [r for r in rows if str(r["id"]) not in cache]
        print(f"{len(rows) - len(to_process)} already in cache; generating {len(to_process)} event keys...")

        for i, row in enumerate(to_process):
            if i and i % 25 == 0:
                print(f"  ...{i}/{len(to_process)}")
                _save_cache(cache)
            event_key, entities = await _generate_event_key(row["title"], row["summary"] or "")
            cache[str(row["id"])] = {"event_key": event_key, "key_entities": entities}
        _save_cache(cache)

        # Embed all keys (batched) for rows we're about to write.
        pending = [(r["id"], cache[str(r["id"])]) for r in rows if str(r["id"]) in cache]
        report = [
            f"Rows needing backfill (last {days}d): {len(rows)}",
            f"Event keys ready: {len(pending)}",
            "",
            "Sample:",
        ]
        for rid, payload in pending[:15]:
            report.append(f"  {rid}  {payload['event_key'][:110]}")
        report_text = "\n".join(report)
        print("\n" + report_text)
        with open(REPORT_PATH, "w") as f:
            f.write(report_text)

        if not commit:
            print(f"\nDry run — no rows written. Report at {REPORT_PATH}. Re-run with --commit.")
            return

        print(f"\nEmbedding {len(pending)} event keys and writing rows...")
        BATCH = 64
        written = 0
        for start in range(0, len(pending), BATCH):
            chunk = pending[start : start + BATCH]
            vectors = await embed_texts([p["event_key"] for _, p in chunk])
            await conn.executemany(
                """
                UPDATE articles
                SET event_key = $2, key_entities = $3, dedup_embedding = $4::float8[]::vector
                WHERE id = $1
                """,
                [
                    (rid, p["event_key"], p["key_entities"], vec)
                    for (rid, p), vec in zip(chunk, vectors)
                ],
            )
            written += len(chunk)
            print(f"  wrote {written}/{len(pending)}")
        print(f"Done — {written} rows updated.")
    finally:
        await conn.close()


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--commit", action="store_true", help="Write to the DB (default: dry run).")
    parser.add_argument("--days", type=int, default=10, help="Publish-age window to backfill (default 10).")
    args = parser.parse_args()
    asyncio.run(run(commit=args.commit, days=args.days))
