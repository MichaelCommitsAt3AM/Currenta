-- supabase/migrations/20260314185400_create_trending_logs.sql
-- Create trending_logs table to track Google Trends processing hits/misses.

CREATE TABLE IF NOT EXISTS trending_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    region TEXT NOT NULL,
    query TEXT NOT NULL,
    traffic INTEGER,
    action TEXT NOT NULL, -- 'BOOSTED', 'INGEST_TRIGGERED', 'ERROR', 'SKIPPED'
    anchor_title TEXT,
    anchor_url TEXT,
    match_count INTEGER DEFAULT 0,
    error_message TEXT
);

CREATE INDEX IF NOT EXISTS trending_logs_created_at_idx ON trending_logs (created_at DESC);
CREATE INDEX IF NOT EXISTS trending_logs_query_idx ON trending_logs (query);
