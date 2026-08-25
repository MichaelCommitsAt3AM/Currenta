-- supabase/fix_embedding_dimensions.sql
--
-- SUPERSEDED — do not run this file. It was originally run out-of-band
-- directly in the Supabase SQL Editor, never captured as a dated migration,
-- and its own IVFFlat index doesn't even match what ended up live (an HNSW
-- index instead — some later, still-undocumented manual step created that).
-- That process gap (schema changes applied outside supabase/migrations/) is
-- also what caused the interest_embedding dimension bug fixed in
-- 20260824120000_fix_interest_embedding_dims.sql. This file's actual
-- intended effect is now captured properly, idempotently, and safely
-- guarded against re-running on already-correct data in
-- supabase/migrations/20260824140000_reconcile_article_embedding_dims.sql —
-- kept here only for historical reference.
-- ─────────────────────────────────────────────────────────────────────────────
-- MIGRATION: Fix embedding column + switch to voyage-3.5-lite (1024 dims)
--
-- Problem 1: live table embedding size may not match the active embedding model.
--            vectors from llama3.1, causing an INSERT error.
-- Problem 2: pgvector IVFFlat max = 2000 dims, so vector(4096) can't be indexed.
--
-- Solution:  Use Voyage voyage-3.5-lite (1024 dims).
--            Keep llama3.1 for summarisation only.
--            Reset column to vector(1024) and recreate the index cleanly.
--
-- ⚠️  This drops all existing embedding values (column is wiped + re-added).
--    Re-trigger the ingest edge function after running this to repopulate.
--
-- Run in Supabase SQL Editor → project trfqhobnkgtfccrdsexa
-- ─────────────────────────────────────────────────────────────────────────────

BEGIN;

-- 1. Drop the old index (must go first, bound to column type)
DROP INDEX IF EXISTS articles_embedding_idx;

-- 2. Drop and re-add embedding column as vector(1024)
ALTER TABLE articles DROP COLUMN IF EXISTS embedding;
ALTER TABLE articles ADD COLUMN embedding vector(1024);

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
-- Expected output: vector(1024)
-- ─────────────────────────────────────────────────────────────────────────────
