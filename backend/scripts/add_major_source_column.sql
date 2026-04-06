-- Add is_major_source column to articles table
ALTER TABLE articles ADD COLUMN IF NOT EXISTS is_major_source BOOLEAN DEFAULT FALSE;

-- Create an index for faster tiered sorting
CREATE INDEX IF NOT EXISTS idx_articles_major_source ON articles (is_major_source) WHERE is_major_source = TRUE;
