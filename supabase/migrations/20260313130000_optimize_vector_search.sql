-- supabase/migrations/20260313130000_optimize_vector_search.sql

-- Update match_recent_articles to include a 7-day lookback.
-- This significantly reduces the vector search space and prevents performance degradation 
-- as the articles table grows into the hundreds of thousands.

DROP FUNCTION IF EXISTS match_recent_articles(vector, float, int);

CREATE OR REPLACE FUNCTION match_recent_articles(
  query_embedding vector(1536),
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
    -- 1. Index-backed time filter (Crucial for performance)
    articles.published_at > (now() - interval '7 days')
    -- 2. Similarity threshold
    AND 1 - (articles.embedding <=> query_embedding) > similarity_threshold
  ORDER BY articles.embedding <=> query_embedding
  LIMIT match_count;
END;
$$;
