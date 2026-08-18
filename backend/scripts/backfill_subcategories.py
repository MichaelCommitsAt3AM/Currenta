"""
One-off backfill: resolve the free-text `articles.subcategory` values written
before the canonical taxonomy (backend/services/taxonomy.py) existed into
proper `articles.subcategories` slugs.

The 20260818140000_add_subcategories_array.sql migration already wrapped the
raw `subcategory` string into a 1-element `subcategories` array as a stopgap
(so the column is never NULL/empty for previously-ingested rows). This script
overwrites that stopgap with a properly resolved canonical slug, using the
same two-layer resolution as live ingestion (backend/services/ingestion.py
parse_llm_response): the taxonomy alias map first, then — for whatever the
alias map can't resolve — a cosine-similarity match against each taxonomy
node's embedded label text (display name + aliases).

Run from the repo root, inside the `api` or `worker` container (it needs
DATABASE_URL/DB_SSL_MODE and an embedding provider configured the same way
ingestion.py does):

    python -m backend.scripts.backfill_subcategories          # dry run (default)
    python -m backend.scripts.backfill_subcategories --commit  # writes to the DB

Writes its report to /tmp, not the repo root — see CLAUDE.md: `api`/`worker`
run with `uvicorn --reload` watching the whole mounted repo, so a file
written under the repo root triggers a spurious restart mid-run.
"""
import argparse
import asyncio
import math
import os
from collections import defaultdict
from typing import Dict, List, Optional

import asyncpg
from dotenv import load_dotenv

from backend.services.taxonomy import get_taxonomy
from backend.services.ingestion import embed_text

load_dotenv()

EMBED_MATCH_THRESHOLD = 0.75
REPORT_PATH = "/tmp/backfill_subcategories_report.txt"


def _cosine_similarity(a: List[float], b: List[float]) -> float:
    dot = sum(x * y for x, y in zip(a, b))
    norm_a = math.sqrt(sum(x * x for x in a))
    norm_b = math.sqrt(sum(y * y for y in b))
    if norm_a == 0 or norm_b == 0:
        return 0.0
    return dot / (norm_a * norm_b)


async def _get_connection() -> asyncpg.Connection:
    database_url = os.environ["DATABASE_URL"]
    ssl_mode = os.environ.get("DB_SSL_MODE", "require")
    ssl_param = False if ssl_mode == "disable" else ssl_mode
    return await asyncpg.connect(dsn=database_url, ssl=ssl_param)


async def _build_reference_embeddings(taxonomy) -> Dict[str, List[float]]:
    print(f"Embedding {len(taxonomy.all_slugs)} taxonomy node labels for fallback matching...")
    embeddings = {}
    for slug in taxonomy.all_slugs:
        embeddings[slug] = await embed_text(taxonomy.label_text(slug))
    return embeddings


async def _resolve_unmatched_via_embedding(
    unmatched_raw_values: List[str],
    reference_embeddings: Dict[str, List[float]],
) -> Dict[str, Optional[tuple]]:
    """raw string -> (slug, similarity) or None, for everything the alias map missed."""
    print(f"Embedding {len(unmatched_raw_values)} unique unmatched raw values...")
    resolved = {}
    for i, raw in enumerate(unmatched_raw_values):
        if i % 50 == 0 and i > 0:
            print(f"  ...{i}/{len(unmatched_raw_values)}")
        try:
            raw_embedding = await embed_text(raw)
        except Exception as e:
            print(f"  [WARN] Failed to embed {raw!r}: {e}")
            resolved[raw] = None
            continue
        best_slug, best_sim = None, 0.0
        for slug, ref_embedding in reference_embeddings.items():
            sim = _cosine_similarity(raw_embedding, ref_embedding)
            if sim > best_sim:
                best_slug, best_sim = slug, sim
        if best_slug and best_sim >= EMBED_MATCH_THRESHOLD:
            resolved[raw] = (best_slug, best_sim)
        else:
            resolved[raw] = None
    return resolved


async def run(commit: bool) -> None:
    taxonomy = get_taxonomy()
    conn = await _get_connection()
    try:
        rows = await conn.fetch(
            "SELECT id, subcategory, categories FROM articles "
            "WHERE subcategory IS NOT NULL AND subcategory <> ''"
        )
        print(f"Found {len(rows)} articles with a legacy subcategory value.")

        alias_matched: Dict[str, str] = {}   # article id -> slug
        unmatched_by_raw: Dict[str, List[str]] = defaultdict(list)  # raw -> [article ids]

        for row in rows:
            slug = taxonomy.match(row["subcategory"], row["categories"])
            if slug:
                alias_matched[row["id"]] = slug
            else:
                unmatched_by_raw[row["subcategory"]].append(row["id"])

        print(f"Alias map resolved {len(alias_matched)}/{len(rows)} rows "
              f"({len(unmatched_by_raw)} distinct unmatched raw values).")

        embed_matched: Dict[str, str] = {}
        embed_scores: Dict[str, float] = {}
        still_unmatched_raw: List[str] = []

        if unmatched_by_raw:
            reference_embeddings = await _build_reference_embeddings(taxonomy)
            resolution = await _resolve_unmatched_via_embedding(
                list(unmatched_by_raw.keys()), reference_embeddings
            )
            for raw, result in resolution.items():
                article_ids = unmatched_by_raw[raw]
                if result:
                    slug, sim = result
                    for aid in article_ids:
                        embed_matched[aid] = slug
                        embed_scores[aid] = sim
                else:
                    still_unmatched_raw.append(raw)

        total_matched = len(alias_matched) + len(embed_matched)
        report_lines = [
            f"Total rows with a legacy subcategory: {len(rows)}",
            f"Resolved via alias map: {len(alias_matched)}",
            f"Resolved via embedding fallback (>= {EMBED_MATCH_THRESHOLD}): {len(embed_matched)}",
            f"Unresolved: {len(rows) - total_matched}",
            f"Total resolved: {total_matched} ({100 * total_matched / max(len(rows), 1):.1f}%)",
            "",
            "Unresolved raw subcategory values (candidates for new taxonomy nodes):",
        ]
        for raw in sorted(still_unmatched_raw):
            report_lines.append(f"  - {raw!r} ({len(unmatched_by_raw[raw])} articles)")

        report = "\n".join(report_lines)
        print("\n" + report)
        with open(REPORT_PATH, "w") as f:
            f.write(report)
        print(f"\nFull report written to {REPORT_PATH}")

        if not commit:
            print("\nDry run only — no rows written. Re-run with --commit to apply.")
            return

        print(f"\nWriting {total_matched} resolved subcategories to the database...")
        updates = [(aid, [slug]) for aid, slug in alias_matched.items()]
        updates += [(aid, [slug]) for aid, slug in embed_matched.items()]
        await conn.executemany(
            "UPDATE articles SET subcategories = $2 WHERE id = $1",
            updates,
        )
        print(f"Done — {len(updates)} rows updated.")
    finally:
        await conn.close()


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--commit", action="store_true",
        help="Actually write resolved subcategories to the DB. Without this, only a report is produced.",
    )
    args = parser.parse_args()
    asyncio.run(run(commit=args.commit))
