-- supabase/migrations/20260421113000_recommendation_engine_core.sql

-- 1. Create Article Likes Table
CREATE TABLE IF NOT EXISTS article_likes (
  user_id UUID NOT NULL,
  article_id UUID NOT NULL REFERENCES articles(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, article_id)
);

-- Index for fast user lookups
CREATE INDEX IF NOT EXISTS article_likes_user_id_idx ON article_likes(user_id);

-- Enable RLS
ALTER TABLE article_likes ENABLE ROW LEVEL SECURITY;

-- Policies for article_likes
CREATE POLICY "Users can view their own likes" ON article_likes
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can toggle their own likes" ON article_likes
  FOR ALL USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);


-- 2. Add Interest Embedding to Profiles (Cache)
-- This stores the weighted average of the user's liked articles.
ALTER TABLE user_profiles ADD COLUMN IF NOT EXISTS interest_embedding vector(768);


-- 3. Create the Weighted Recalculation Function
-- This function implements "Option B": Recalculate based on last 60 days with exponential decay.
-- Decay Formula: exp(-0.069 * days_old)  [Gives ~50% weight at 10 days, ~1% at 60 days]
CREATE OR REPLACE FUNCTION update_user_interest_vector(target_user_id UUID)
RETURNS VOID AS $$
DECLARE
    new_vector vector(768);
BEGIN
    -- Calculate the weighted average
    SELECT 
        (SUM(a.embedding * (exp(-0.069 * EXTRACT(EPOCH FROM (now() - al.created_at)) / 86400.0))::float8) / 
         (SUM(exp(-0.069 * EXTRACT(EPOCH FROM (now() - al.created_at)) / 86400.0)))::float8)::vector(768)
    INTO new_vector
    FROM article_likes al
    JOIN articles a ON al.article_id = a.id
    WHERE al.user_id = target_user_id
      AND al.created_at > now() - INTERVAL '60 days'
      AND a.embedding IS NOT NULL;

    -- Update the cache in user_profiles
    UPDATE user_profiles 
    SET interest_embedding = new_vector,
        updated_at = now()
    WHERE user_id = target_user_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- 4. Triggers to keep the cache fresh
-- Updates the user's interest vector whenever they like or unlike an article.
CREATE OR REPLACE FUNCTION trigger_update_user_interests()
RETURNS TRIGGER AS $$
BEGIN
    PERFORM update_user_interest_vector(COALESCE(NEW.user_id, OLD.user_id));
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS on_article_like_change ON article_likes;
CREATE TRIGGER on_article_like_change
AFTER INSERT OR DELETE ON article_likes
FOR EACH ROW EXECUTE FUNCTION trigger_update_user_interests();


-- 5. HNSW Index for fast similarity search
-- Note: We use 768 dimensions for Nomic v1.5
-- If the index already exists on 'embedding', this might be redundant but 
-- specifically optimized for cosine similarity.
CREATE INDEX IF NOT EXISTS articles_personalized_idx 
ON articles USING hnsw (embedding vector_cosine_ops);


-- 6. Update Migration Function
-- Ensure that likes are transferred when an anonymous user signs in.
CREATE OR REPLACE FUNCTION migrate_user_data(old_uid UUID, new_uid UUID)
RETURNS VOID AS $$
BEGIN
    -- Transfer Interests (Categories)
    INSERT INTO user_interests (user_id, category)
    SELECT new_uid, category FROM user_interests WHERE user_id = old_uid
    ON CONFLICT DO NOTHING;

    -- Transfer Sub-Interests
    INSERT INTO user_sub_interests (user_id, sub_category)
    SELECT new_uid, sub_category FROM user_sub_interests WHERE user_id = old_uid
    ON CONFLICT DO NOTHING;

    -- Transfer View History
    INSERT INTO article_views (user_id, article_id)
    SELECT new_uid, article_id FROM article_views WHERE user_id = old_uid
    ON CONFLICT DO NOTHING;

    -- Transfer Dislikes
    INSERT INTO article_dislikes (user_id, article_id)
    SELECT new_uid, article_id FROM article_dislikes WHERE user_id = old_uid
    ON CONFLICT DO NOTHING;
    
    -- Transfer Favorites
    INSERT INTO article_favorites (user_id, article_id)
    SELECT new_uid, article_id FROM article_favorites WHERE user_id = old_uid
    ON CONFLICT DO NOTHING;

    -- Transfer Likes (New)
    INSERT INTO article_likes (user_id, article_id, created_at)
    SELECT new_uid, article_id, created_at FROM article_likes WHERE user_id = old_uid
    ON CONFLICT DO NOTHING;

    -- Transfer Profile (preferred_country)
    INSERT INTO user_profiles (user_id, preferred_country, updated_at)
    SELECT new_uid, preferred_country, updated_at FROM user_profiles WHERE user_id = old_uid
    ON CONFLICT (user_id) DO UPDATE 
    SET preferred_country = EXCLUDED.preferred_country,
        updated_at = EXCLUDED.updated_at
    WHERE user_profiles.updated_at < EXCLUDED.updated_at;
    
    -- Trigger recalculation for the new user ID
    PERFORM update_user_interest_vector(new_uid);

    -- Cleanup old session
    DELETE FROM user_interests WHERE user_id = old_uid;
    DELETE FROM user_sub_interests WHERE user_id = old_uid;
    DELETE FROM article_views WHERE user_id = old_uid;
    DELETE FROM article_dislikes WHERE user_id = old_uid;
    DELETE FROM article_favorites WHERE user_id = old_uid;
    DELETE FROM article_likes WHERE user_id = old_uid;
    DELETE FROM user_profiles WHERE user_id = old_uid;

EXCEPTION WHEN OTHERS THEN
    RAISE WARNING 'User data migration failed for old_uid: % to new_uid: %. Error: %', old_uid, new_uid, SQLERRM;
    RAISE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
