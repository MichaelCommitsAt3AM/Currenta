-- supabase/migrations/20260311122500_harden_remaining_tables.sql

-- 1. Harden feed_jobs ---------------------------------------------------------
ALTER TABLE feed_jobs ENABLE ROW LEVEL SECURITY;

-- Only service_role can access the job queue
CREATE POLICY "Service role can manage feed jobs" ON feed_jobs
  FOR ALL USING (auth.role() = 'service_role') 
  WITH CHECK (auth.role() = 'service_role');


-- 2. Harden llm_usage ---------------------------------------------------------
ALTER TABLE llm_usage ENABLE ROW LEVEL SECURITY;

-- Only service_role can access usage logs
CREATE POLICY "Service role can manage llm usage" ON llm_usage
  FOR ALL USING (auth.role() = 'service_role')
  WITH CHECK (auth.role() = 'service_role');


-- 3. Harden local_news_sync ---------------------------------------------------
ALTER TABLE local_news_sync ENABLE ROW LEVEL SECURITY;

-- Service role manages sync state
CREATE POLICY "Service role can manage local news sync" ON local_news_sync
  FOR ALL USING (auth.role() = 'service_role')
  WITH CHECK (auth.role() = 'service_role');

-- Allow authenticated/anon to view sync state (read-only info)
CREATE POLICY "Public can view local news sync status" ON local_news_sync
  FOR SELECT USING (true);


-- 4. Harden user_ai_usage -----------------------------------------------------
ALTER TABLE user_ai_usage ENABLE ROW LEVEL SECURITY;

-- Service role (backend) updates usage counters
CREATE POLICY "Service role can manage user ai usage" ON user_ai_usage
  FOR ALL USING (auth.role() = 'service_role')
  WITH CHECK (auth.role() = 'service_role');

-- Users can view their own usage limits
CREATE POLICY "Users can view their own ai usage" ON user_ai_usage
  FOR SELECT USING (auth.uid() = user_id);


-- 5. Tighten ingestion_logs ---------------------------------------------------
-- The previous migration had a broad 'USING (true)' policy. Let's restrict it.
DO $$
BEGIN
  DROP POLICY IF EXISTS "Service role can do everything on logs" ON ingestion_logs;
EXCEPTION WHEN undefined_object THEN
  NULL;
END
$$;

ALTER TABLE ingestion_logs ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Service role can manage ingestion logs" ON ingestion_logs
  FOR ALL USING (auth.role() = 'service_role')
  WITH CHECK (auth.role() = 'service_role');
