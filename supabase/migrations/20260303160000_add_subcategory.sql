-- 1. Add subcategory to articles table
ALTER TABLE articles
ADD COLUMN IF NOT EXISTS subcategory TEXT;

-- 2. Add category_bias to feed_jobs table
ALTER TABLE feed_jobs
ADD COLUMN IF NOT EXISTS category_bias TEXT DEFAULT 'neutral';
