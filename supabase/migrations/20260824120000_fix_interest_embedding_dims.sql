-- Fix a dimension mismatch that has silently disabled personalized ranking.
--
-- user_profiles.interest_embedding was added as vector(768) in
-- 20260421113000_recommendation_engine_core.sql, assuming the old Ollama
-- nomic-embed-text provider. But articles.embedding has been vector(1024)
-- (Voyage voyage-4-lite) since supabase/fix_embedding_dimensions.sql, which
-- was hand-run in the Supabase SQL Editor and never turned into a tracked
-- migration. Every write into interest_embedding since — both cold-start
-- seeding in backend/api/feed.py and the like-weighted
-- update_user_interest_vector() below — has been throwing
-- "expected 768 dimensions, not 1024" and getting swallowed.
--
-- Confirmed on the home server before writing this: 0 of 13 user_profiles
-- rows have a populated interest_embedding despite 94 article_likes and
-- users active since May 2026. The embedding-based "Personalized" ranking
-- bucket in /feed has never actually activated.
--
-- Safe to drop-and-recreate the column: interest_embedding is 100% NULL
-- today. The guard below re-verifies that at migration time — if it fires,
-- STOP and investigate before proceeding, since this migration is not
-- written to preserve existing values.

DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM user_profiles WHERE interest_embedding IS NOT NULL
    ) THEN
        RAISE EXCEPTION 'Aborting: user_profiles.interest_embedding has non-NULL rows. This migration assumes it is empty (see file header) — investigate before proceeding.';
    END IF;
END $$;

ALTER TABLE user_profiles DROP COLUMN IF EXISTS interest_embedding;
ALTER TABLE user_profiles ADD COLUMN interest_embedding vector(1024);

-- Re-declare update_user_interest_vector with matching dimensions (was
-- vector(768) in 20260429135500_fix_personalization_aggregation.sql).
-- Logic is otherwise unchanged: time-decayed weighted average of liked
-- articles' embeddings over the trailing 60 days, invoked from a debounced
-- background task (backend/services/personalization.py) rather than a
-- trigger — see that migration for why the trigger was removed.
CREATE OR REPLACE FUNCTION update_user_interest_vector(target_user_id UUID)
RETURNS VOID AS $$
DECLARE
    new_vector vector(1024);
BEGIN
    SELECT
        (AVG(a.embedding * (exp(-0.069 * EXTRACT(EPOCH FROM (now() - al.created_at)) / 86400.0))::float8) /
         NULLIF(AVG(exp(-0.069 * EXTRACT(EPOCH FROM (now() - al.created_at)) / 86400.0)), 0))::vector(1024)
    INTO new_vector
    FROM article_likes al
    JOIN articles a ON al.article_id = a.id
    WHERE al.user_id = target_user_id
      AND al.created_at > now() - INTERVAL '60 days'
      AND a.embedding IS NOT NULL;

    UPDATE user_profiles
    SET interest_embedding = new_vector,
        updated_at = now()
    WHERE user_id = target_user_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
