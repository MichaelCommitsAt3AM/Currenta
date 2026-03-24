-- supabase/migrations/20260322080000_implement_hnsw_index.sql

-- Drop existing IVFFlat index.
-- According to pgvector docs, HNSW is generally better and doesn't require training (unlike IVFFlat).
-- It will speed up similarity search from O(N) to O(log N).

BEGIN;

-- 1. Drop the old IVFFlat index
DROP INDEX IF EXISTS articles_embedding_idx;

-- 2. Create the new HNSW index. 
-- Using vector_cosine_ops as that is what articles.embedding is mostly queried with.
-- m=16, ef_construction=64 are good balanced defaults.
CREATE INDEX articles_embedding_hnsw_idx 
  ON articles 
  USING hnsw (embedding vector_cosine_ops)
  WITH (m = 16, ef_construction = 64);

-- 3. Update the match_recent_articles function to use the same logic (it already does, but just to be sure)
-- This function is used for duplicate detection and helps the planner choose the right index.

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
  WHERE
    -- Time filter helps restrict the search space, though HNSW works well even without it.
    articles.published_at > (now() - interval '7 days')
    AND 1 - (articles.embedding <=> query_embedding) > similarity_threshold
  ORDER BY articles.embedding <=> query_embedding
  LIMIT match_count;
END;
$$;

COMMIT;
