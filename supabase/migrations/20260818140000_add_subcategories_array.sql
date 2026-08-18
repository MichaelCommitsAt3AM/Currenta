-- Add a multi-value `subcategories` array alongside the existing single
-- `subcategory` TEXT column, mirroring the categories/category migration
-- pattern (20260303180000_multi_category.sql). Values are canonical slugs
-- from taxonomy/taxonomy.json (backend/services/taxonomy.py), not free text.
--
-- `subcategory` is kept populated for one release for backward compatibility
-- with any code still reading it, and should be dropped in a follow-up
-- migration once the client/backend fully cut over to `subcategories`.

ALTER TABLE articles
  ADD COLUMN IF NOT EXISTS subcategories TEXT[] NOT NULL DEFAULT '{}';

-- Backfill: wrap the existing single value so already-ingested rows aren't
-- left empty pending the taxonomy backfill script (which will overwrite
-- these with properly resolved canonical slugs).
UPDATE articles
  SET subcategories = ARRAY[subcategory]
  WHERE subcategories = '{}' AND subcategory IS NOT NULL AND subcategory <> '';

CREATE INDEX IF NOT EXISTS articles_subcategories_gin_idx
  ON articles USING gin (subcategories);
