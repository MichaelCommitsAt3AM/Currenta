-- supabase/migrations/20260311191000_add_ingestion_method_to_articles.sql
ALTER TABLE "public"."articles" ADD COLUMN "ingestion_method" text;

-- Comment for clarity
COMMENT ON COLUMN "public"."articles"."ingestion_method" IS 'Indicates if the article content was extracted via full scraping or fell back to RSS context. Values: scraper, rss';

-- Default existing rows to rss if they exist (conservative estimate)
UPDATE "public"."articles" SET "ingestion_method" = 'rss' WHERE "ingestion_method" IS NULL;
