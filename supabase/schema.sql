-- supabase/schema.sql
-- Run this in your Supabase SQL Editor to set up the database schema.

-- ==========================================
-- 1. EXTENSIONS
-- ==========================================
CREATE EXTENSION IF NOT EXISTS vector;
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- ==========================================
-- 2. TABLES
-- ==========================================

-- 2.1 Articles table
CREATE TABLE IF NOT EXISTS articles (
    id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title             TEXT NOT NULL,
    summary           TEXT NOT NULL,
    original_url      TEXT NOT NULL UNIQUE,
    source_name       TEXT NOT NULL,
    source_favicon_url TEXT,
    published_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    is_paywalled      BOOLEAN NOT NULL DEFAULT false,
    cluster_id        UUID,
    embedding_legacy_768 vector(768),
    image_url         TEXT,
    content_hash      TEXT,
    summary_model     TEXT,
    subcategory       TEXT,
    categories        TEXT[] NOT NULL DEFAULT '{world}',
    country_code      VARCHAR(2),
    created_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
    ingestion_method  TEXT,
    trend_score       DOUBLE PRECISION DEFAULT 0.0,
    last_trend_update TIMESTAMPTZ,
    ranking_score     DOUBLE PRECISION DEFAULT 0.0,
    embedding         vector(768)
);

-- 2.2 Feed Jobs table
CREATE TABLE IF NOT EXISTS feed_jobs (
    id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    feed_url      TEXT NOT NULL,
    category      TEXT NOT NULL,
    status        TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'processing', 'completed', 'failed')),
    attempts      INTEGER NOT NULL DEFAULT 0,
    locked_at     TIMESTAMPTZ,
    last_error    TEXT,
    created_at    TIMESTAMPTZ DEFAULT now(),
    updated_at    TIMESTAMPTZ DEFAULT now(),
    category_bias TEXT DEFAULT 'neutral'
);

-- 2.3 User Activity & Profiles
CREATE TABLE IF NOT EXISTS user_profiles (
    user_id           UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    preferred_country VARCHAR(2),
    is_admin          BOOLEAN DEFAULT false,
    created_at        TIMESTAMPTZ DEFAULT now(),
    updated_at        TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS user_interests (
    user_id    UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    category   TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (user_id, category)
);

CREATE TABLE IF NOT EXISTS user_sub_interests (
    user_id      UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    sub_category TEXT NOT NULL,
    created_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (user_id, sub_category)
);

CREATE TABLE IF NOT EXISTS article_views (
    user_id   UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    article_id UUID NOT NULL REFERENCES articles(id) ON DELETE CASCADE,
    viewed_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (user_id, article_id)
);

CREATE TABLE IF NOT EXISTS article_favorites (
    user_id    UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    article_id UUID NOT NULL REFERENCES articles(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (user_id, article_id)
);

CREATE TABLE IF NOT EXISTS article_dislikes (
    user_id    UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    article_id UUID NOT NULL REFERENCES articles(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (user_id, article_id)
);

CREATE TABLE IF NOT EXISTS user_ai_usage (
    user_id       UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    daily_count   INTEGER DEFAULT 0,
    last_reset_at DATE DEFAULT CURRENT_DATE
);

-- 2.4 Internal Logs & Sync
CREATE TABLE IF NOT EXISTS ingestion_logs (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    original_url        TEXT NOT NULL,
  trigger_source      TEXT,
    source_name         TEXT,
    status              TEXT NOT NULL,
  dedup_stage         TEXT,
  dedup_decision      TEXT,
  semantic_similarity DOUBLE PRECISION,
  similarity_threshold DOUBLE PRECISION,
  matched_article_id  UUID,
  matched_cluster_id  UUID,
    error_type          TEXT,
    error_message       TEXT,
    has_text            BOOLEAN DEFAULT false,
    has_image           BOOLEAN DEFAULT false,
    extracted_image_url TEXT,
    content_preview     TEXT,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
    resolved_url        TEXT
);

CREATE TABLE IF NOT EXISTS ingestion_blocks (
    id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    created_at TIMESTAMPTZ DEFAULT now(),
    pattern    TEXT NOT NULL,
    type       TEXT DEFAULT 'domain' CHECK (type IN ('domain', 'path', 'regex')),
    is_active  BOOLEAN DEFAULT true,
    reason     TEXT
);

CREATE TABLE IF NOT EXISTS trending_logs (
    id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    created_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
    region       TEXT NOT NULL,
    query        TEXT NOT NULL,
    traffic      INTEGER,
    action       TEXT NOT NULL,
    anchor_title TEXT,
    anchor_url   TEXT,
    match_count  INTEGER DEFAULT 0,
    error_message TEXT
);

CREATE TABLE IF NOT EXISTS local_news_sync (
    country_code VARCHAR(2) PRIMARY KEY,
    last_fetched_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS llm_usage (
    id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    created_at TIMESTAMPTZ DEFAULT now()
);

-- ==========================================
-- 3. INDEXES
-- ==========================================

-- Articles
CREATE INDEX IF NOT EXISTS articles_embedding_hnsw_idx ON articles USING hnsw (embedding vector_cosine_ops) WITH (m = 16, ef_construction = 64);
CREATE INDEX IF NOT EXISTS articles_published_at_idx ON articles (published_at DESC);
CREATE INDEX IF NOT EXISTS articles_created_at_idx ON articles (created_at DESC);
CREATE INDEX IF NOT EXISTS articles_trend_score_idx ON articles (trend_score DESC);
CREATE UNIQUE INDEX IF NOT EXISTS articles_content_hash_idx ON articles (content_hash) WHERE content_hash IS NOT NULL;
CREATE INDEX IF NOT EXISTS articles_categories_gin_idx ON articles USING GIN (categories);
CREATE INDEX IF NOT EXISTS articles_ranking_score_idx ON articles (ranking_score DESC);
CREATE INDEX IF NOT EXISTS idx_articles_category_country ON articles (country_code, categories);

-- Feed Jobs
CREATE UNIQUE INDEX IF NOT EXISTS feed_jobs_active_unique ON feed_jobs (feed_url) WHERE (status = ANY (ARRAY['pending'::text, 'processing'::text]));
CREATE INDEX IF NOT EXISTS feed_jobs_status_idx ON feed_jobs (status);

-- User Activity
CREATE INDEX IF NOT EXISTS article_views_user_recent_idx ON article_views (user_id, viewed_at DESC);
CREATE INDEX IF NOT EXISTS article_favorites_user_id_idx ON article_favorites (user_id);
CREATE INDEX IF NOT EXISTS article_dislikes_user_id_idx ON article_dislikes (user_id);
CREATE INDEX IF NOT EXISTS user_interests_user_id_idx ON user_interests (user_id);
CREATE INDEX IF NOT EXISTS user_sub_interests_user_id_idx ON user_sub_interests (user_id);

-- Logs
CREATE INDEX IF NOT EXISTS ingestion_logs_created_at_idx ON ingestion_logs (created_at DESC);
CREATE INDEX IF NOT EXISTS ingestion_logs_original_url_idx ON ingestion_logs (original_url);
CREATE INDEX IF NOT EXISTS ingestion_logs_status_idx ON ingestion_logs (status);
CREATE INDEX IF NOT EXISTS ingestion_logs_dedup_decision_idx ON ingestion_logs (dedup_decision);
CREATE INDEX IF NOT EXISTS idx_ingestion_blocks_active ON ingestion_blocks (is_active) WHERE (is_active = true);
CREATE INDEX IF NOT EXISTS trending_logs_created_at_idx ON trending_logs (created_at DESC);
CREATE INDEX IF NOT EXISTS trending_logs_query_idx ON trending_logs (query);
CREATE INDEX IF NOT EXISTS llm_usage_created_at_idx ON llm_usage (created_at);

-- ==========================================
-- 4. FUNCTIONS
-- ==========================================

-- 4.1 Match recent articles by vector similarity
CREATE OR REPLACE FUNCTION match_recent_articles(
  query_embedding vector(768),
  similarity_threshold float,
  match_count int
)
RETURNS TABLE (
  id UUID,
  similarity float
)
LANGUAGE plpgsql
AS $$
BEGIN
  RETURN QUERY
  SELECT
    articles.id,
    1 - (articles.embedding <=> query_embedding) AS similarity
  FROM articles
  WHERE
    articles.published_at > (now() - interval '7 days')
    AND 1 - (articles.embedding <=> query_embedding) > similarity_threshold
  ORDER BY articles.embedding <=> query_embedding
  LIMIT match_count;
END;
$$;

-- 4.2 Claim a feed job
CREATE OR REPLACE FUNCTION claim_feed_job()
RETURNS SETOF feed_jobs
LANGUAGE plpgsql
AS $$
begin
  return query
  update feed_jobs
  set status = 'processing',
      locked_at = now(),
      attempts = attempts + 1,
      updated_at = now()
  where id = (
    select id
    from feed_jobs
    where status = 'pending' or (status = 'failed' and attempts < 3)
    order by created_at asc
    limit 1
    for update skip locked
  )
  returning *;
end;
$$;

-- 4.3 Reset stale feed jobs
CREATE OR REPLACE FUNCTION reset_stale_feed_jobs(stale_minutes integer DEFAULT 10)
RETURNS integer
LANGUAGE plpgsql
AS $$
DECLARE
  reset_count int;
BEGIN
  UPDATE feed_jobs
  SET    status     = 'pending',
         updated_at = now()
  WHERE  status    = 'processing'
    AND  locked_at < now() - (stale_minutes || ' minutes')::interval;

  GET DIAGNOSTICS reset_count = ROW_COUNT;
  RETURN reset_count;
END;
$$;

-- 4.4 Migrate user data (for account linking/merging)
CREATE OR REPLACE FUNCTION migrate_user_data(old_uid uuid, new_uid uuid)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER
AS $$
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

    -- Transfer Profile
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
$$;

-- ==========================================
-- 5. ROW LEVEL SECURITY (RLS)
-- ==========================================

-- Enable RLS on all tables
ALTER TABLE articles ENABLE ROW LEVEL SECURITY;
ALTER TABLE feed_jobs ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_interests ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_sub_interests ENABLE ROW LEVEL SECURITY;
ALTER TABLE article_views ENABLE ROW LEVEL SECURITY;
ALTER TABLE article_favorites ENABLE ROW LEVEL SECURITY;
ALTER TABLE article_dislikes ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_ai_usage ENABLE ROW LEVEL SECURITY;
ALTER TABLE ingestion_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE ingestion_blocks ENABLE ROW LEVEL SECURITY;
ALTER TABLE trending_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE local_news_sync ENABLE ROW LEVEL SECURITY;
ALTER TABLE llm_usage ENABLE ROW LEVEL SECURITY;

-- 5.1 Articles (Public read, Service manage)
CREATE POLICY "Public read" ON articles FOR SELECT USING (true);
CREATE POLICY "Service insert" ON articles FOR INSERT WITH CHECK (auth.role() = 'service_role');
CREATE POLICY "Service update" ON articles FOR UPDATE USING (auth.role() = 'service_role');

-- 5.2 User Profiles & Preferences (User manage own data)
CREATE POLICY "Users can manage their own profile" ON user_profiles USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can view their own profile" ON user_profiles FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can manage their own interests" ON user_interests USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can view their own interests" ON user_interests FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can manage their own sub-interests" ON user_sub_interests USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can view their own sub-interests" ON user_sub_interests FOR SELECT USING (auth.uid() = user_id);

-- 5.3 User Interactions (Views, Favorites, Dislikes)
CREATE POLICY "Users can record their own views" ON article_views FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can view their own history" ON article_views FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can toggle their own favorites" ON article_favorites USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can view their own favorites" ON article_favorites FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can toggle their own dislikes" ON article_dislikes USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can view their own dislikes" ON article_dislikes FOR SELECT USING (auth.uid() = user_id);

-- 5.4 AI Usage
CREATE POLICY "Users can view their own ai usage" ON user_ai_usage FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Service role can manage user ai usage" ON user_ai_usage USING (auth.role() = 'service_role') WITH CHECK (auth.role() = 'service_role');

-- 5.5 System & Service Role Policies
CREATE POLICY "Service role can manage feed jobs" ON feed_jobs USING (auth.role() = 'service_role') WITH CHECK (auth.role() = 'service_role');
CREATE POLICY "Service role can manage ingestion logs" ON ingestion_logs USING (auth.role() = 'service_role') WITH CHECK (auth.role() = 'service_role');
CREATE POLICY "Service role can manage ingestion blocks" ON ingestion_blocks USING (auth.role() = 'service_role') WITH CHECK (auth.role() = 'service_role');
CREATE POLICY "Allow read access for all on ingestion blocks" ON ingestion_blocks FOR SELECT USING (true);
CREATE POLICY "Service role can manage local news sync" ON local_news_sync USING (auth.role() = 'service_role') WITH CHECK (auth.role() = 'service_role');
CREATE POLICY "Public can view local news sync status" ON local_news_sync FOR SELECT USING (true);
CREATE POLICY "Service role can manage llm usage" ON llm_usage USING (auth.role() = 'service_role') WITH CHECK (auth.role() = 'service_role');
