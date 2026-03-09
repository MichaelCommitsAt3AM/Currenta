-- supabase/migrations/20260308213000_ingestion_logs.sql
CREATE TABLE IF NOT EXISTS ingestion_logs (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  original_url      TEXT NOT NULL,
  source_name       TEXT,
  status            TEXT NOT NULL, -- 'FAILED', 'DEGRADED', 'SUCCESS_NO_IMAGE', 'SUCCESS'
  error_type        TEXT,          -- 'SCRAPER_ERROR', 'IMAGE_MISSING', 'LLM_ERROR', 'DUPLICATE', 'SKIPPED_JUNK'
  error_message     TEXT,
  has_text          BOOLEAN DEFAULT false,
  has_image         BOOLEAN DEFAULT false,
  extracted_image_url TEXT,
  content_preview   TEXT,          -- First 200 chars or so for debugging
  created_at        TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Add index for performance
CREATE INDEX IF NOT EXISTS ingestion_logs_created_at_idx ON ingestion_logs (created_at DESC);
CREATE INDEX IF NOT EXISTS ingestion_logs_original_url_idx ON ingestion_logs (original_url);
CREATE INDEX IF NOT EXISTS ingestion_logs_status_idx ON ingestion_logs (status);

-- Enable RLS (Row Level Security) - Only service_role should write
ALTER TABLE ingestion_logs ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Service role can do everything on logs" ON ingestion_logs
  FOR ALL USING (true) WITH CHECK (true);
