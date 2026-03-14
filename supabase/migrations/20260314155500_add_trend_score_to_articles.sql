-- supabase/migrations/20260314155500_add_trend_score_to_articles.sql
-- Add trend_score and last_trend_update columns to the articles table for the Trending feature.

ALTER TABLE articles 
ADD COLUMN IF NOT EXISTS trend_score DOUBLE PRECISION DEFAULT 0.0,
ADD COLUMN IF NOT EXISTS last_trend_update TIMESTAMPTZ;

-- Add index on trend_score for efficient ranking
CREATE INDEX IF NOT EXISTS articles_trend_score_idx ON articles (trend_score DESC);
