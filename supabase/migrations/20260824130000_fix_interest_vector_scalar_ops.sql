-- Fix update_user_interest_vector(): it has never actually run successfully.
--
-- Discovered while backfilling after 20260824120000_fix_interest_embedding_dims.sql:
-- running the function against real data throws
--   "operator does not exist: vector * double precision"
-- pgvector 0.8.2 only defines vector*vector (elementwise), vector+vector,
-- vector-vector — there is no vector*scalar or any vector/... operator at
-- all. The original SQL (`a.embedding * (weight)::float8`, and dividing the
-- weighted sum by a scalar) was invalid from the moment it was written in
-- 20260429135500_fix_personalization_aggregation.sql; the dimension bug
-- fixed in 20260824120000 was hiding a second, independent bug behind it.
--
-- Fix: pgvector supports vector*vector, so "vector * scalar" is done by
-- building a same-dimension vector filled with the scalar
-- (array_fill(scalar, ARRAY[1024])::vector) and using elementwise multiply.
-- Division by the scalar weight-sum is done the same way, multiplying by
-- its reciprocal, since pgvector has no division operator at all.
--
-- Verified against live data in a rolled-back transaction before writing
-- this: correctly produces a 1024-dim vector for a user with likes inside
-- the 60-day window, and leaves interest_embedding NULL for a user whose
-- only like is 89 days old (outside the window) — matching the original
-- intended behavior.

CREATE OR REPLACE FUNCTION update_user_interest_vector(target_user_id UUID)
RETURNS VOID AS $$
DECLARE
    new_vector vector(1024);
BEGIN
    WITH weighted AS (
        SELECT
            a.embedding AS emb,
            exp(-0.069 * EXTRACT(EPOCH FROM (now() - al.created_at)) / 86400.0)::float8 AS w
        FROM article_likes al
        JOIN articles a ON al.article_id = a.id
        WHERE al.user_id = target_user_id
          AND al.created_at > now() - INTERVAL '60 days'
          AND a.embedding IS NOT NULL
    ),
    agg AS (
        SELECT
            AVG(emb * array_fill(w, ARRAY[1024])::vector) AS weighted_sum_avg,
            NULLIF(AVG(w), 0) AS weight_avg
        FROM weighted
    )
    SELECT
        CASE WHEN weight_avg IS NULL THEN NULL
             ELSE (weighted_sum_avg * array_fill((1.0 / weight_avg)::float8, ARRAY[1024])::vector)::vector(1024)
        END
    INTO new_vector
    FROM agg;

    -- If no likes found (or all outside the window), new_vector will be
    -- NULL, which is the correct state (clearing interests).
    UPDATE user_profiles
    SET interest_embedding = new_vector,
        updated_at = now()
    WHERE user_id = target_user_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
