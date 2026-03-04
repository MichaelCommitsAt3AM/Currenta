-- supabase/migrations/20260305000000_track_views.sql

-- 1. Create viewed articles table
CREATE TABLE IF NOT EXISTS article_views (
  user_id UUID NOT NULL,
  article_id UUID NOT NULL REFERENCES articles(id) ON DELETE CASCADE,
  viewed_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, article_id)
);

-- 2. Index for faster filtering in feed
CREATE INDEX IF NOT EXISTS article_views_user_id_idx ON article_views (user_id);

-- 3. Row Level Security
ALTER TABLE article_views ENABLE ROW LEVEL SECURITY;

-- Allow users to see their own views
CREATE POLICY "Users can view their own history" ON article_views
  FOR SELECT USING (auth.uid() = user_id);

-- Allow users to record their own views
-- This needs to work for both 'authenticated' and 'anon' roles if using anonymous auth
CREATE POLICY "Users can record their own views" ON article_views
  FOR INSERT WITH CHECK (auth.uid() = user_id);
