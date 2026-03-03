-- =============================================================================
-- Migration: Harden the queue system
-- Adds: content_hash + summary_model columns on articles
--       partial unique index to prevent duplicate active jobs
--       pg_cron schedule to drain the queue every minute
-- =============================================================================

-- 1. New columns on articles ---------------------------------------------------

ALTER TABLE articles
  ADD COLUMN IF NOT EXISTS content_hash   TEXT,
  ADD COLUMN IF NOT EXISTS summary_model  TEXT;

-- Unique index on content_hash (sparse — only enforced when the value is non-null)
CREATE UNIQUE INDEX IF NOT EXISTS articles_content_hash_idx
  ON articles (content_hash)
  WHERE content_hash IS NOT NULL;

-- 2. Partial unique index on feed_jobs ----------------------------------------
-- Prevents the orchestrator from queuing the same feed twice while it's still
-- active (pending or processing). Completed / failed rows are excluded, so the
-- same feed can be re-queued after a full run.

CREATE UNIQUE INDEX IF NOT EXISTS feed_jobs_active_unique
  ON feed_jobs (feed_url)
  WHERE status IN ('pending', 'processing');

-- 3. Status constraint on feed_jobs (safety guard) ----------------------------

DO $$
BEGIN
  ALTER TABLE feed_jobs
    ADD CONSTRAINT feed_jobs_status_check
    CHECK (status IN ('pending', 'processing', 'completed', 'failed'));
EXCEPTION WHEN duplicate_object THEN
  NULL; -- constraint already exists, ignore
END
$$;

-- 4. pg_cron: drain the queue every minute ------------------------------------
-- This calls the process-feed-job Edge Function automatically.
-- Replace <PROJECT_REF> and <SERVICE_ROLE_KEY> with your actual values,
-- then run this block manually in the SQL editor (or via a Supabase secret).
--
-- SELECT cron.schedule(
--   'drain-feed-queue',       -- unique job name
--   '* * * * *',              -- every minute
--   $$
--     SELECT net.http_post(
--       url     := 'https://<PROJECT_REF>.supabase.co/functions/v1/process-feed-job',
--       headers := jsonb_build_object(
--         'Content-Type',  'application/json',
--         'Authorization', 'Bearer <SERVICE_ROLE_KEY>'
--       ),
--       body    := '{}'::jsonb
--     );
--   $$
-- );

-- 5. Stale-job recovery function ----------------------------------------------
-- Alternative to the in-function reset: a DB-side function that can also be
-- called via cron or manually if needed.

CREATE OR REPLACE FUNCTION reset_stale_feed_jobs(stale_minutes int DEFAULT 10)
RETURNS int
LANGUAGE plpgsql
AS $$
DECLARE
  reset_count int;
BEGIN
  UPDATE feed_jobs
  SET    status     = 'pending',
         updated_at = now()
  WHERE  status    = 'processing'
    AND  locked_at < now() - (stale_minutes || ' minutes')::interval;

  GET DIAGNOSTICS reset_count = ROW_COUNT;
  RETURN reset_count;
END;
$$;
