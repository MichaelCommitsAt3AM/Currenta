-- Fold the last untracked out-of-band schema change into migrations.
--
-- Tracked history shows articles.embedding go Voyage(1024) ->
-- Nomic(768) (20260318103000_switch_to_voyage_embeddings.sql,
-- 20260319081500_switch_to_nomic_v1_5.sql). But production has been running
-- Voyage(1024) for a long time — confirmed live: vector(1024), 11,983
-- populated rows, articles_embedding_hnsw_idx. That switch back was made via
-- supabase/fix_embedding_dimensions.sql, run directly in the Supabase SQL
-- Editor and never captured as a dated migration — the same process gap
-- that caused the interest_embedding dimension bug fixed earlier today
-- (20260824120000_fix_interest_embedding_dims.sql). This migration exists so
-- a full migration replay against a fresh database reaches the same end
-- state as production, instead of dead-ending at 768 dims.
--
-- Guarded to be a safe no-op against the current live DB: it only performs
-- the destructive drop/recreate (which wipes embedding values — pgvector
-- dimensions are fixed, there is no in-place resize) when the column is NOT
-- already vector(1024). Verified this evaluates to a no-op against
-- production before writing it.

DO $$
DECLARE
    current_type text;
BEGIN
    SELECT format_type(atttypid, atttypmod) INTO current_type
    FROM pg_attribute
    WHERE attrelid = 'articles'::regclass
      AND attname = 'embedding'
      AND attnum > 0
      AND NOT attisdropped;

    IF current_type IS DISTINCT FROM 'vector(1024)' THEN
        RAISE NOTICE 'articles.embedding is % — migrating to vector(1024). This drops existing embedding values; re-run ingestion to repopulate.', current_type;

        DROP INDEX IF EXISTS articles_embedding_idx;
        DROP INDEX IF EXISTS articles_embedding_hnsw_idx;
        DROP INDEX IF EXISTS articles_personalized_idx;

        ALTER TABLE articles DROP COLUMN IF EXISTS embedding;
        ALTER TABLE articles ADD COLUMN embedding vector(1024);
    ELSE
        RAISE NOTICE 'articles.embedding already vector(1024) — skipping (no-op against production).';
    END IF;
END $$;

-- Matches the index actually live in production (verified via pg_indexes).
-- 20260421113000_recommendation_engine_core.sql created an HNSW index under
-- a different name (articles_personalized_idx) that does not exist on the
-- live DB today — that CREATE INDEX apparently never took effect there;
-- this is the index name production has actually been using.
CREATE INDEX IF NOT EXISTS articles_embedding_hnsw_idx
  ON articles
  USING hnsw (embedding vector_cosine_ops)
  WITH (m = 16, ef_construction = 64);

-- match_recent_articles is dead code — nothing in backend/ calls it (no
-- supabase.rpc() call anywhere, no Edge Functions exist in this repo despite
-- supabase/match_articles_rpc.sql's comment claiming otherwise). Real
-- semantic-dedup ranking happens inline in
-- backend/services/ingestion.py:find_cluster_match(). Kept only for
-- reference; redefined here with an unconstrained `vector` parameter to
-- match what's actually live (production's copy was never dimension-locked
-- to begin with, unlike every tracked migration's version) so it can't drift
-- out of sync with articles.embedding's dimension again.
DROP FUNCTION IF EXISTS match_recent_articles(vector, float, int);

CREATE OR REPLACE FUNCTION match_recent_articles(
  query_embedding vector,
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
