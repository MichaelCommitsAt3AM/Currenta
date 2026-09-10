-- Early-access waitlist captured by the marketing site (landing/) via
-- POST /api/waitlist (backend/api/waitlist.py). Not auth data — a separate,
-- low-sensitivity list of email addresses that asked for a build link.
--
-- RLS is enabled with NO policies on purpose: the self-hosted PostgREST exposes
-- the `public` schema, and we never want anon/authenticated REST clients to be
-- able to read the signup list. The backend connects as the table owner and
-- bypasses RLS, so /api/waitlist keeps working.
--
-- DDL only. Apply manually to the home server:
--   docker compose exec -T db psql -U postgres -d postgres \
--     -f - < supabase/migrations/20260910200000_add_waitlist_signups.sql

CREATE TABLE IF NOT EXISTS waitlist_signups (
    id            BIGSERIAL PRIMARY KEY,
    email         TEXT        NOT NULL UNIQUE,     -- stored lowercased/trimmed by the API
    created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
    referrer      TEXT,                            -- document.referrer at submit time
    user_agent    TEXT,
    ip_hash       TEXT,                            -- sha256(salt:ip), never the raw IP
    suspected_bot BOOLEAN     NOT NULL DEFAULT false,
    source        TEXT        NOT NULL DEFAULT 'landing',
    notified_at   TIMESTAMPTZ                      -- set when the build link is sent
);

CREATE INDEX IF NOT EXISTS idx_waitlist_signups_created ON waitlist_signups (created_at DESC);
CREATE INDEX IF NOT EXISTS idx_waitlist_signups_unnotified
    ON waitlist_signups (created_at) WHERE notified_at IS NULL;

ALTER TABLE waitlist_signups ENABLE ROW LEVEL SECURITY;
