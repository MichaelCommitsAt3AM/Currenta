-- supabase/migrations/20260313120000_add_favorites_table.sql

-- 1. Create Article Favorites Table
CREATE TABLE IF NOT EXISTS article_favorites (
  user_id UUID NOT NULL,
  article_id UUID NOT NULL REFERENCES articles(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, article_id)
);

-- Index for fast user lookups
CREATE INDEX IF NOT EXISTS article_favorites_user_id_idx ON article_favorites(user_id);

-- Enable RLS
ALTER TABLE article_favorites ENABLE ROW LEVEL SECURITY;

-- Policies for article_favorites
CREATE POLICY "Users can view their own favorites" ON article_favorites
  FOR SELECT USING (auth.uid() = user_id);

-- Allow both insert and delete for toggling
CREATE POLICY "Users can toggle their own favorites" ON article_favorites
  FOR ALL USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);


-- 2. Update Migration Function to include favorites
CREATE OR REPLACE FUNCTION migrate_user_data(old_uid UUID, new_uid UUID)
RETURNS VOID AS $$
BEGIN
    -- Transfer Interests
    INSERT INTO user_interests (user_id, category)
    SELECT new_uid, category FROM user_interests WHERE user_id = old_uid
    ON CONFLICT DO NOTHING;

    -- Transfer View History
    -- Handle cases where both old_uid and new_uid might have viewed the same article
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
    
    -- Cleanup old session
    DELETE FROM user_interests WHERE user_id = old_uid;
    DELETE FROM article_views WHERE user_id = old_uid;
    DELETE FROM article_dislikes WHERE user_id = old_uid;
    DELETE FROM article_favorites WHERE user_id = old_uid;

EXCEPTION WHEN OTHERS THEN
    RAISE WARNING 'User data migration failed for old_uid: % to new_uid: %. Error: %', old_uid, new_uid, SQLERRM;
    RAISE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
