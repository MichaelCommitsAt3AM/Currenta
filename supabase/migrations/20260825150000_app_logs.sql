-- Structured sink for backend application logs (api + worker), separate from
-- ingestion_logs (which tracks per-article pipeline outcomes). Populated by
-- backend/core/log_sink.py's PostgresLogHandler, attached alongside the
-- existing stdout handler in backend/core/logging_config.py.
CREATE TABLE IF NOT EXISTS app_logs (
    id          BIGSERIAL PRIMARY KEY,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    level       TEXT NOT NULL,          -- DEBUG / INFO / WARNING / ERROR / CRITICAL
    level_no    SMALLINT NOT NULL,      -- logging module numeric level, for >= comparisons
    service     TEXT NOT NULL,          -- 'api' | 'worker'
    logger      TEXT NOT NULL,          -- e.g. backend.services.ingestion
    component   TEXT,                   -- leading [Bracket] tag convention already used in
                                         -- log messages across the codebase (e.g. 'Image-Storage',
                                         -- 'View-Flush', 'embed_text'), extracted at insert time
                                         -- so it's filterable without parsing message text.
    message     TEXT NOT NULL,
    module      TEXT,
    func        TEXT,
    line        INTEGER,
    exc_text    TEXT,                   -- formatted traceback, when exc_info was set
    signature   TEXT,                   -- hash of message with numbers/uuids/urls normalized
                                         -- out, so repeated failures (retry storms, rate-limit
                                         -- bursts) group into one row instead of thousands
    extra       JSONB
);

CREATE INDEX IF NOT EXISTS idx_app_logs_created_id ON app_logs (created_at DESC, id DESC);
CREATE INDEX IF NOT EXISTS idx_app_logs_level_created ON app_logs (level_no, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_app_logs_service_created ON app_logs (service, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_app_logs_logger_created ON app_logs (logger, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_app_logs_signature_created ON app_logs (signature, created_at DESC);
