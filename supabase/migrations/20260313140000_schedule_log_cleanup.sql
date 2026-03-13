-- 1. Enable pg_cron and pg_net extensions
CREATE EXTENSION IF NOT EXISTS "pg_cron";
CREATE EXTENSION IF NOT EXISTS "pg_net";

-- 2. Schedule the cleanup job
-- This schedules the cleanup to run every day at midnight (UTC).

SELECT cron.schedule(
  'cleanup-ingestion-logs',
  '0 0 * * *', -- Every day at midnight
  $$
    SELECT net.http_post(
      url     := 'https://trfqhobnkgtfccrdsexa.supabase.co/functions/v1/cleanup-ingestion-logs',
      headers := jsonb_build_object(
        'Content-Type',  'application/json',
        'Authorization', 'Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRyZnFob2Jua2d0ZmNjcmRzZXhhIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3MjI4MjU3MywiZXhwIjoyMDg3ODU4NTczfQ.0ofHRzMPda84oLLCGkQJtMHJNtRg54udZGXE9I-paeA'
      ),
      body    := '{}'::jsonb
    );
  $$
);

-- PRO TIP: If you just want to delete the logs via SQL (more efficient),
-- you can use this instead in pg_cron:
-- DELETE FROM ingestion_logs WHERE created_at < now() - interval '7 days';
