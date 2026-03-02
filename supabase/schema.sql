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
  source_name       TEXT NOT NULL,
  source_favicon_url TEXT,
  published_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  category          TEXT NOT NULL DEFAULT 'world',
  is_paywalled      BOOLEAN NOT NULL DEFAULT false,
  cluster_id        UUID,
  -- 768-dim for nomic-embed-text (dedicated embedding model)
  embedding         vector(768)
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

-- 5. Row Level Security
ALTER TABLE articles ENABLE ROW LEVEL SECURITY;

-- Allow anon users to SELECT (read-only public feed)
CREATE POLICY "Public read" ON articles
  FOR SELECT USING (true);

-- Only service_role (Edge Functions) can INSERT/UPDATE
CREATE POLICY "Service insert" ON articles
  FOR INSERT WITH CHECK (auth.role() = 'service_role');

CREATE POLICY "Service update" ON articles
  FOR UPDATE USING (auth.role() = 'service_role');
