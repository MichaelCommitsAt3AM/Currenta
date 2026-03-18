-- Switch article embeddings to OpenAI text-embedding-3-small (1536 dims).
-- This migration resets stored embeddings because pgvector dimensions are fixed.

BEGIN;

-- Drop vector index before changing the column.
DROP INDEX IF EXISTS articles_embedding_idx;

-- Recreate embedding column at 1536 dimensions.
ALTER TABLE articles DROP COLUMN IF EXISTS embedding;
ALTER TABLE articles ADD COLUMN embedding vector(1536);

-- Recreate IVFFlat index.
CREATE INDEX articles_embedding_idx
  ON articles
  USING ivfflat (embedding vector_cosine_ops)
  WITH (lists = 10);

-- Update function signature to use the new embedding dimension.
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
    articles.published_at > (now() - interval '7 days')
    AND 1 - (articles.embedding <=> query_embedding) > similarity_threshold
  ORDER BY articles.embedding <=> query_embedding
  LIMIT match_count;
END;
$$;

COMMIT;
