-- Add structured semantic dedup diagnostics to ingestion logs.

BEGIN;

ALTER TABLE ingestion_logs
  ADD COLUMN IF NOT EXISTS dedup_stage TEXT,
  ADD COLUMN IF NOT EXISTS dedup_decision TEXT,
  ADD COLUMN IF NOT EXISTS semantic_similarity DOUBLE PRECISION,
  ADD COLUMN IF NOT EXISTS similarity_threshold DOUBLE PRECISION,
  ADD COLUMN IF NOT EXISTS matched_article_id UUID,
  ADD COLUMN IF NOT EXISTS matched_cluster_id UUID;

CREATE INDEX IF NOT EXISTS ingestion_logs_dedup_decision_idx
  ON ingestion_logs (dedup_decision);

COMMIT;
