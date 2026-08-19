-- articles_feed has an explicit column list (not SELECT *), so the
-- subcategories column added in 20260818140000_add_subcategories_array.sql
-- isn't visible through it yet. feed.py's ARTICLE_COLUMNS and the new
-- subcategory-boost ORDER BY (subcategories && $n) both query this view.

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
    subcategories,
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
    expires_at,
    (((1.0)::double precision + COALESCE(trend_score, (0.0)::double precision)) * (exp((('-0.05'::numeric * EXTRACT(epoch FROM (now() - published_at))) / 3600.0)))::double precision) AS ranking_score
   FROM articles;
