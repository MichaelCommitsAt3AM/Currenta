#!/usr/bin/env bash
#
# Drops the cached feed orderings on the home server so ranking/personalization
# changes show up on the next app open instead of waiting out the 4h session TTL.
#
# Deliberately targeted, NOT `FLUSHALL` — the same Redis also holds:
#   pending_view_buffer   article views not yet written to Postgres (would be lost)
#   ingest:rejected:*     the 12h ingestion failure cooldown (flushing re-runs the
#                         LLM on every previously-rejected URL, and poisons any
#                         in-flight measurement of what that cooldown saves)
#
# Usage (on the home server, or via `ssh homeserver`):
#   scripts/flush-feed-cache.sh          # feed sessions only (safe default)
#   scripts/flush-feed-cache.sh --seen   # also clear per-user "already viewed" sets,
#                                        # so the whole article pool is servable again
set -euo pipefail

cd "$(dirname "$0")/.."

patterns=("session_articles:*")
if [[ "${1:-}" == "--seen" ]]; then
    patterns+=("user_seen_v2:*" "user_state:*")
elif [[ -n "${1:-}" ]]; then
    echo "unknown option: $1 (expected --seen)" >&2
    exit 1
fi

for pattern in "${patterns[@]}"; do
    deleted=$(docker compose exec -T redis sh -c \
        "redis-cli --scan --pattern '$pattern' | xargs -r redis-cli del" | tail -1)
    echo "flushed ${deleted:-0} keys matching '$pattern'"
done
