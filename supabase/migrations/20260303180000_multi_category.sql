-- Migration: Convert `category` (TEXT) → `categories` (TEXT[]) on articles table.
-- Existing single-category articles are wrapped into a one-element array so no data is lost.

-- 1. Add the new column
ALTER TABLE articles
  ADD COLUMN IF NOT EXISTS categories TEXT[] NOT NULL DEFAULT '{world}';

-- 2. Copy existing single category into the new array column
UPDATE articles
  SET categories = ARRAY[category]
  WHERE categories = '{world}' AND category IS NOT NULL;

-- 3. Drop the old column (subcategory stays unchanged)
ALTER TABLE articles
  DROP COLUMN IF EXISTS category;

-- 4. GIN index for efficient array containment queries (@> operator)
CREATE INDEX IF NOT EXISTS articles_categories_gin_idx
  ON articles USING gin (categories);
