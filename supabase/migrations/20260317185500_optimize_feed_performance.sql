-- supabase/migrations/20260317185500_optimize_feed_performance.sql

-- 1. Add ranking_score column to articles
ALTER TABLE articles ADD COLUMN IF NOT EXISTS ranking_score DOUBLE PRECISION DEFAULT 0.0;

-- 2. Create index for fast ranking-based retrieval
CREATE INDEX IF NOT EXISTS articles_ranking_score_idx ON articles (ranking_score DESC);

-- 3. Replace the existing user_id index with a composite index that supports sorting by viewed_at
DROP INDEX IF EXISTS article_views_user_id_idx;
CREATE INDEX IF NOT EXISTS article_views_user_recent_idx ON article_views (user_id, viewed_at DESC);
