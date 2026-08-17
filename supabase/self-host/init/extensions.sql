-- Extensions the hosted project actually uses (matched via pg_extension
-- there). pg_graphql is deliberately NOT installed -- nothing in the
-- codebase uses GraphQL, and PGRST_DB_SCHEMAS in docker-compose.yml is
-- scoped to just 'public' to match.
CREATE EXTENSION IF NOT EXISTS vector;
CREATE EXTENSION IF NOT EXISTS pg_stat_statements;
CREATE EXTENSION IF NOT EXISTS pgsodium;
CREATE EXTENSION IF NOT EXISTS supabase_vault;
CREATE EXTENSION IF NOT EXISTS pg_cron;
CREATE EXTENSION IF NOT EXISTS pg_net;
