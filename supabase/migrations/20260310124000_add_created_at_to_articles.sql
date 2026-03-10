-- Add created_at column to articles table
ALTER TABLE articles ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ NOT NULL DEFAULT now();

-- Index for sorting by creation time if needed in the future
CREATE INDEX IF NOT EXISTS articles_created_at_idx ON articles (created_at DESC);
