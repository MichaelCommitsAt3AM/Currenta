-- supabase/migrations/20260315220000_add_missing_personalization_tables.sql

-- 1. Create User Sub-Interests Table
CREATE TABLE IF NOT EXISTS user_sub_interests (
  user_id UUID NOT NULL,
  sub_category TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, sub_category)
);

-- Index for fast user lookups
CREATE INDEX IF NOT EXISTS user_sub_interests_user_id_idx ON user_sub_interests(user_id);

-- Enable RLS
ALTER TABLE user_sub_interests ENABLE ROW LEVEL SECURITY;

-- Policies for user_sub_interests
CREATE POLICY "Users can view their own sub-interests" ON user_sub_interests
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can manage their own sub-interests" ON user_sub_interests
  FOR ALL USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);


-- 2. Create User Profiles Table (for country settings)
CREATE TABLE IF NOT EXISTS user_profiles (
  user_id UUID PRIMARY KEY NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  preferred_country TEXT,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Note: We don't force a foreign key on guest users, so we might need to relax the constraint 
-- or handle guest profiles differently. Since profiles are usually for logged-in users:
ALTER TABLE user_profiles DROP CONSTRAINT IF EXISTS user_profiles_user_id_fkey;

-- Enable RLS
ALTER TABLE user_profiles ENABLE ROW LEVEL SECURITY;

-- Policies for user_profiles
CREATE POLICY "Users can view their own profile" ON user_profiles
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can manage their own profile" ON user_profiles
  FOR ALL USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);


-- 3. Update Migration Function to include missing tables
CREATE OR REPLACE FUNCTION migrate_user_data(old_uid UUID, new_uid UUID)
RETURNS VOID AS $$
BEGIN
    -- Transfer Interests
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

    -- Transfer Profile (preferred_country)
    -- Use the most recent update if both exist, otherwise transfer from old
    INSERT INTO user_profiles (user_id, preferred_country, updated_at)
    SELECT new_uid, preferred_country, updated_at FROM user_profiles WHERE user_id = old_uid
    ON CONFLICT (user_id) DO UPDATE 
    SET preferred_country = EXCLUDED.preferred_country,
        updated_at = EXCLUDED.updated_at
    WHERE user_profiles.updated_at < EXCLUDED.updated_at;
    
    -- Cleanup old session
    DELETE FROM user_interests WHERE user_id = old_uid;
    DELETE FROM user_sub_interests WHERE user_id = old_uid;
    DELETE FROM article_views WHERE user_id = old_uid;
    DELETE FROM article_dislikes WHERE user_id = old_uid;
    DELETE FROM article_favorites WHERE user_id = old_uid;
    DELETE FROM user_profiles WHERE user_id = old_uid;

EXCEPTION WHEN OTHERS THEN
    RAISE WARNING 'User data migration failed for old_uid: % to new_uid: %. Error: %', old_uid, new_uid, SQLERRM;
    RAISE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
