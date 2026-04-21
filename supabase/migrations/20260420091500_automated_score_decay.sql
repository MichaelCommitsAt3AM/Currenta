-- supabase/migrations/20260420091500_automated_score_decay.sql

-- 1. Ensure pg_cron is enabled (it should be, but safety first)
CREATE EXTENSION IF NOT EXISTS "pg_cron";

-- 2. Schedule the ranking score decay to run every hour.
-- This ensures articles "cool down" even if the local worker is offline.
-- The formula is: (1.0 + trend_score) * exp(-0.05 * age_in_hours)
-- We target articles from the last 72 hours.

SELECT cron.schedule(
  'decay-article-ranks',
  '0 * * * *', -- Every hour on the hour
  $$
    UPDATE articles 
    SET ranking_score = ((1.0 + trend_score) * exp(-0.05 * extract(epoch from (now() - published_at))/3600))
    WHERE published_at > NOW() - INTERVAL '72 hours'
  $$
);

-- Note: We don't need to manually refresh the ranking_score index, 
-- Postgres handles this automatically when the column is updated.
