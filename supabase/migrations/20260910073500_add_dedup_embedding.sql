-- supabase/migrations/20260910073500_add_dedup_embedding.sql
--
-- Gives semantic deduplication its own signal, separate from articles.embedding.
--
-- Why: find_cluster_match() (backend/services/ingestion.py) has always compared
-- embed(title + " " + summary). The 65-word summary carries each outlet's
-- framing, so three articles about the *same* event written from different
-- angles embed at only ~0.73 cosine — under the 0.75 dup threshold — and all
-- three get ingested. (Confirmed 2026-09-10 on the Amazon cargo plane crash:
-- ids 51c7b24d.., 1c80a13.., 11f7cda7.. — pairwise 0.726-0.747.) Lowering the
-- threshold isn't viable: a sampled 0.70-0.75 band is ~80% genuinely-distinct
-- "related coverage" (same company / region / weather system, different story).
--
-- Fix: the summarizer LLM now also emits `event_key` — one framing-free
-- sentence of who/what/where/outcome. Two outlets covering one event produce
-- near-identical keys, so embed(event_key) clusters them well above threshold
-- WITHOUT dragging merely-related stories up with them. That vector lives in
-- `dedup_embedding` and is the ONLY thing find_cluster_match reads.
--
-- articles.embedding is untouched — it still embeds title+summary and still
-- backs personalized ranking (feed.py), the like-derived interest vector
-- (update_user_interest_vector), trend->article matching (trending.py) and
-- related-articles, all of which want the richer text.
--
-- `key_entities` is populated now but not yet consumed — it's for a later
-- gray-zone lexical check (require >=2 shared entities when dedup similarity
-- is just below threshold).
--
-- Backfill note: find_cluster_match only looks back DUPLICATE_LOOKBACK_DAYS
-- (7), so only articles from the last ~10 days ever need dedup_embedding.
-- backend/scripts/backfill_dedup_embedding.py handles that window; everything
-- older stays NULL by design and the find_cluster_match query filters on
-- `dedup_embedding IS NOT NULL`.
--
-- Hosted / Cloud Run catch-up: this migration + the ingestion.py changes must
-- be applied there too before Cloud Run's worker ingests again (see CLAUDE.md).

ALTER TABLE articles ADD COLUMN IF NOT EXISTS event_key       TEXT;
ALTER TABLE articles ADD COLUMN IF NOT EXISTS key_entities    TEXT[];
ALTER TABLE articles ADD COLUMN IF NOT EXISTS dedup_embedding vector(1024);

-- Same index params as articles_embedding_hnsw_idx.
CREATE INDEX IF NOT EXISTS articles_dedup_embedding_hnsw_idx
    ON articles USING hnsw (dedup_embedding vector_cosine_ops) WITH (m = 16, ef_construction = 64);
