-- supabase/schema.sql
-- Run this in your Supabase SQL Editor to set up the articles table.

-- 1. Enable pgvector extension
CREATE EXTENSION IF NOT EXISTS vector;

-- 2. Articles table
CREATE TABLE IF NOT EXISTS articles (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  title             TEXT NOT NULL,
  summary           TEXT NOT NULL,
  original_url      TEXT NOT NULL UNIQUE,
  image_url         TEXT,
  source_name       TEXT NOT NULL,
  source_favicon_url TEXT,
  published_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
  categories        TEXT[] NOT NULL DEFAULT '{world}',
  subcategory       TEXT,
  is_paywalled      BOOLEAN NOT NULL DEFAULT false,
  ingestion_method  TEXT, -- 'scraper' or 'rss' (for analysis)
  cluster_id        UUID,
  content_hash      TEXT UNIQUE,
  summary_model     TEXT,
  -- 768-dim for nomic-embed-text (dedicated embedding model)
  embedding         vector(768),
  country_code      VARCHAR(2),
  trend_score      DOUBLE PRECISION DEFAULT 0.0,
  ranking_score    DOUBLE PRECISION DEFAULT 0.0,
  last_trend_update TIMESTAMPTZ
);

-- 3. IVFFlat index for fast cosine similarity search
--    nomic-embed-text = 768 dims, well within the 2000-dim IVFFlat limit.
--    lists=10 is fine for dev; bump to 100+ once you have >10k rows.
CREATE INDEX IF NOT EXISTS articles_embedding_idx
  ON articles
  USING ivfflat (embedding vector_cosine_ops)
  WITH (lists = 10);

-- 4. Recency index for fast time-range deduplication queries
CREATE INDEX IF NOT EXISTS articles_published_at_idx
  ON articles (published_at DESC);

-- 5. Insertion recency index
CREATE INDEX IF NOT EXISTS articles_created_at_idx
  ON articles (created_at DESC);

-- 5.5 Trend score index
CREATE INDEX IF NOT EXISTS articles_trend_score_idx
  ON articles (trend_score DESC);

-- 6. Content hash index for fast lookup
CREATE UNIQUE INDEX IF NOT EXISTS articles_content_hash_idx
  ON articles (content_hash) WHERE content_hash IS NOT NULL;

-- 7. GIN index for category filtering
CREATE INDEX IF NOT EXISTS articles_categories_gin_idx
  ON articles USING GIN (categories);

-- 7.5 Index for fast ranking-based retrieval
CREATE INDEX IF NOT EXISTS articles_ranking_score_idx ON articles (ranking_score DESC);

-- 7.6 Compound index for feed filtering
CREATE INDEX IF NOT EXISTS idx_articles_category_country ON articles (country_code, categories);

-- 8. Database Function for vector similarity search
CREATE OR REPLACE FUNCTION match_recent_articles(
  query_embedding vector(768),
  similarity_threshold float,
  match_count int
)
RETURNS TABLE (
  id UUID,
  similarity float
)
LANGUAGE plpgsql
AS $$
BEGIN
  RETURN QUERY
  SELECT
    articles.id,
    1 - (articles.embedding <=> query_embedding) AS similarity
  FROM articles
  WHERE 1 - (articles.embedding <=> query_embedding) > similarity_threshold
  ORDER BY articles.embedding <=> query_embedding
  LIMIT match_count;
END;
$$;

-- 9. Row Level Security
ALTER TABLE articles ENABLE ROW LEVEL SECURITY;

-- Allow anon users to SELECT (read-only public feed)
CREATE POLICY "Public read" ON articles
  FOR SELECT USING (true);

-- Only service_role (Edge Functions) can INSERT/UPDATE
CREATE POLICY "Service insert" ON articles
  FOR INSERT WITH CHECK (auth.role() = 'service_role');

CREATE POLICY "Service update" ON articles
  FOR UPDATE USING (auth.role() = 'service_role');
