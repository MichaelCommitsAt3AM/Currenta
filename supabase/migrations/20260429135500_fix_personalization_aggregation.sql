-- Fix the vector aggregation logic and move to application-triggered async updates.

-- 1. Redefine the update function with AVG() to bypass the lack of SUM(vector) in pgvector.
CREATE OR REPLACE FUNCTION update_user_interest_vector(target_user_id UUID)
RETURNS VOID AS $$
DECLARE
    new_vector vector(768);
BEGIN
    -- Calculate the weighted average using built-in aggregates.
    -- We use AVG(vector * weight) / AVG(weight) because SUM(vector) is not supported.
    SELECT 
        (AVG(a.embedding * (exp(-0.069 * EXTRACT(EPOCH FROM (now() - al.created_at)) / 86400.0))::float8) / 
         NULLIF(AVG(exp(-0.069 * EXTRACT(EPOCH FROM (now() - al.created_at)) / 86400.0)), 0))::vector(768)
    INTO new_vector
    FROM article_likes al
    JOIN articles a ON al.article_id = a.id
    WHERE al.user_id = target_user_id
      AND al.created_at > now() - INTERVAL '60 days'
      AND a.embedding IS NOT NULL;

    -- Update the profile cache. 
    -- If no likes found, new_vector will be NULL, which is the correct state (clearing interests).
    UPDATE user_profiles 
    SET interest_embedding = new_vector,
        updated_at = now()
    WHERE user_id = target_user_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 2. Remove the synchronous trigger. 
-- We are moving this logic to a debounced background task in the FastAPI backend 
-- to improve write performance and reliability.
DROP TRIGGER IF EXISTS on_article_like_change ON article_likes;
