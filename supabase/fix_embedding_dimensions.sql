-- supabase/fix_embedding_dimensions.sql
-- ─────────────────────────────────────────────────────────────────────────────
-- MIGRATION: Fix embedding column + switch to text-embedding-3-small (1536 dims)
--
-- Problem 1: live table embedding size may not match the active embedding model.
--            vectors from llama3.1, causing an INSERT error.
-- Problem 2: pgvector IVFFlat max = 2000 dims, so vector(4096) can't be indexed.
--
-- Solution:  Use OpenAI text-embedding-3-small (1536 dims).
--            Keep llama3.1 for summarisation only.
--            Reset column to vector(1536) and recreate the index cleanly.
--
-- ⚠️  This drops all existing embedding values (column is wiped + re-added).
--    Re-trigger the ingest edge function after running this to repopulate.
--
-- Run in Supabase SQL Editor → project trfqhobnkgtfccrdsexa
-- ─────────────────────────────────────────────────────────────────────────────

BEGIN;

-- 1. Drop the old index (must go first, bound to column type)
DROP INDEX IF EXISTS articles_embedding_idx;

-- 2. Drop and re-add embedding column as vector(1536)
ALTER TABLE articles DROP COLUMN IF EXISTS embedding;
ALTER TABLE articles ADD COLUMN embedding vector(1536);

-- 3. Recreate IVFFlat index
--    lists=10 is fine for dev / small tables; increase to 100 at >10k rows.
CREATE INDEX articles_embedding_idx
  ON articles
  USING ivfflat (embedding vector_cosine_ops)
  WITH (lists = 10);

COMMIT;

-- ─── Verify ──────────────────────────────────────────────────────────────────
-- Run this after the migration to confirm the column type:
--
-- SELECT pg_catalog.format_type(atttypid, atttypmod)
-- FROM pg_attribute
-- WHERE attrelid = 'articles'::regclass AND attname = 'embedding';
--
-- Expected output: vector(1536)
-- ─────────────────────────────────────────────────────────────────────────────
