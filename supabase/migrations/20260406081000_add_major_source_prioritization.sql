-- 2026-04-06: Add is_major_source to articles for feed prioritization
ALTER TABLE articles ADD COLUMN IF NOT EXISTS is_major_source BOOLEAN NOT NULL DEFAULT FALSE;
CREATE INDEX IF NOT EXISTS idx_articles_major_source ON articles (is_major_source) WHERE is_major_source = TRUE;
