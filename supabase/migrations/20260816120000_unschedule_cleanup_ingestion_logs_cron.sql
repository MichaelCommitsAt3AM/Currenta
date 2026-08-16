-- The 'cleanup-ingestion-logs' edge function has been retired in favor of a
-- scheduled job in the always-on worker service (backend/worker.py,
-- cleanup_old_ingestion_logs). Unschedule the pg_cron job that called it.
--
-- NOTE: that pg_cron job's body embedded a service_role key in plaintext
-- (see git history of the now-removed 20260313140000_schedule_log_cleanup.sql).
-- Unscheduling it here stops that key from being used going forward, but the
-- key itself must still be rotated in the Supabase dashboard (Project
-- Settings > API) since it was exposed in a public repo's git history.
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_cron') THEN
    PERFORM cron.unschedule('cleanup-ingestion-logs');
  END IF;
EXCEPTION WHEN OTHERS THEN
  -- Job may not exist (e.g. on a fresh self-hosted DB) — nothing to do.
  NULL;
END $$;
