-- Ensure semantic duplicate lookup uses a 7-day lookback window.
-- Safe to apply even if function is already equivalent.

BEGIN;

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
    articles.published_at > (now() - interval '7 days')
    AND 1 - (articles.embedding <=> query_embedding) > similarity_threshold
  ORDER BY articles.embedding <=> query_embedding
  LIMIT match_count;
END;
$$;

COMMIT;
