-- Add trigger source context so logs can identify where ingestion was initiated.
ALTER TABLE ingestion_logs
ADD COLUMN IF NOT EXISTS trigger_source TEXT;
