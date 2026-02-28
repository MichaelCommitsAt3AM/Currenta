-- supabase/match_articles_rpc.sql
-- Run this in your Supabase SQL Editor AFTER schema.sql
-- This RPC is called by the Edge Function for deduplication.

CREATE OR REPLACE FUNCTION match_recent_articles(
  query_embedding   vector,
  similarity_threshold float,
  match_count       int DEFAULT 1
)
RETURNS TABLE (
  id          UUID,
  similarity  float
)
LANGUAGE sql STABLE
AS $$
  SELECT
    id,
    1 - (embedding <=> query_embedding) AS similarity
  FROM articles
  WHERE
    published_at > now() - interval '24 hours'
    AND 1 - (embedding <=> query_embedding) > similarity_threshold
  ORDER BY embedding <=> query_embedding
  LIMIT match_count;
$$;
