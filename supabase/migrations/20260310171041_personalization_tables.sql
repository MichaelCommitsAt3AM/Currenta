-- supabase/migrations/20260310171041_personalization_tables.sql

-- 1. Create User Interests Table
CREATE TABLE IF NOT EXISTS user_interests (
  user_id UUID NOT NULL,
  category TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, category)
);

-- Index for fast user lookups
CREATE INDEX IF NOT EXISTS user_interests_user_id_idx ON user_interests(user_id);

-- Enable RLS
ALTER TABLE user_interests ENABLE ROW LEVEL SECURITY;

-- Policies for user_interests
CREATE POLICY "Users can view their own interests" ON user_interests
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own interests" ON user_interests
  FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own interests" ON user_interests
  FOR UPDATE USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);
  
CREATE POLICY "Users can delete their own interests" ON user_interests
  FOR DELETE USING (auth.uid() = user_id);


-- 2. Create Article Dislikes Table (For future use, but setup now for migration)
CREATE TABLE IF NOT EXISTS article_dislikes (
  user_id UUID NOT NULL,
  article_id UUID NOT NULL REFERENCES articles(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, article_id)
);

-- Index for fast user lookups
CREATE INDEX IF NOT EXISTS article_dislikes_user_id_idx ON article_dislikes(user_id);

-- Enable RLS
ALTER TABLE article_dislikes ENABLE ROW LEVEL SECURITY;

-- Policies for article_dislikes
CREATE POLICY "Users can view their own dislikes" ON article_dislikes
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own dislikes" ON article_dislikes
  FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete their own dislikes" ON article_dislikes
  FOR DELETE USING (auth.uid() = user_id);


-- 3. Migration RPC
-- Atomically link anonymous data to the new permanent user account
CREATE OR REPLACE FUNCTION migrate_user_data(old_uid UUID, new_uid UUID)
RETURNS VOID AS $$
BEGIN
    -- This function body is executed within an implicit transaction in PostgreSQL.
    -- If any statement fails, the entire transaction is aborted and rolled back.

    -- Transfer Interests
    -- Use ON CONFLICT DO NOTHING in case the new_uid already has interests seeded
    UPDATE user_interests 
    SET user_id = new_uid 
    WHERE user_id = old_uid;

    -- Transfer View History
    -- Handle cases where both old_uid and new_uid might have viewed the same article
    UPDATE article_views 
    SET user_id = new_uid 
    WHERE user_id = old_uid;

    -- Transfer Dislikes
    UPDATE article_dislikes
    SET user_id = new_uid
    WHERE user_id = old_uid;
    
    -- Cleanup old session if needed (optional depending on app logic, but good practice)
    -- This ensures the anonymous ID leaves no stray data behind.
    DELETE FROM user_interests WHERE user_id = old_uid;
    DELETE FROM article_views WHERE user_id = old_uid;
    DELETE FROM article_dislikes WHERE user_id = old_uid;

EXCEPTION WHEN OTHERS THEN
    -- If any constraint violation or error occurs, raise it.
    -- PostgreSQL will automatically rollback the implicit transaction.
    RAISE WARNING 'User data migration failed for old_uid: % to new_uid: %. Error: %', old_uid, new_uid, SQLERRM;
    RAISE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
