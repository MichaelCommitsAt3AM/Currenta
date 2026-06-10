-- supabase/migrations/20260610190000_add_expires_at_to_articles.sql

-- 1. Add expires_at column to articles
ALTER TABLE articles ADD COLUMN IF NOT EXISTS expires_at TIMESTAMPTZ DEFAULT NULL;

-- 2. Create index to optimize expiration-based queries
CREATE INDEX IF NOT EXISTS idx_articles_expires_at ON articles (expires_at) WHERE expires_at IS NOT NULL;

-- 3. Drop and recreate the articles_feed view to include expires_at
DROP VIEW IF EXISTS articles_feed;

CREATE OR REPLACE VIEW articles_feed AS
SELECT id,
    title,
    summary,
    original_url,
    source_name,
    source_favicon_url,
    published_at,
    is_paywalled,
    cluster_id,
    image_url,
    content_hash,
    summary_model,
    subcategory,
    categories,
    country_code,
    created_at,
    ingestion_method,
    trend_score,
    last_trend_update,
    embedding,
    locality_score,
    locality_method,
    locality_evidence,
    is_major_source,
    expires_at, -- Expose the new column
    (((1.0)::double precision + COALESCE(trend_score, (0.0)::double precision)) * (exp((('-0.05'::numeric * EXTRACT(epoch FROM (now() - published_at))) / 3600.0)))::double precision) AS ranking_score
   FROM articles;
