-- supabase/match_articles_rpc.sql
--
-- DEAD CODE as of 20260824140000_reconcile_article_embedding_dims.sql. This
-- file's original comment claimed it's "called by the Edge Function for
-- deduplication" — no such Edge Function exists anywhere in this repo, and
-- nothing in backend/ calls this RPC (no supabase.rpc() call anywhere).
-- Real semantic-dedup ranking is inline SQL in
-- backend/services/ingestion.py:find_cluster_match(). This function is also
-- defined in schema.sql's "4.1 Match recent articles" section — kept here
-- only for reference/history, not something you need to run.

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
    published_at > now() - interval '7 days'
    AND 1 - (embedding <=> query_embedding) > similarity_threshold
  ORDER BY embedding <=> query_embedding
  LIMIT match_count;
$$;
