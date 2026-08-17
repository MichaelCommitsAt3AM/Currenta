-- NOTE: change to your own passwords for production environments
\set pgpass `echo "$POSTGRES_PASSWORD"`

ALTER USER authenticator WITH PASSWORD :'pgpass';
ALTER USER pgbouncer WITH PASSWORD :'pgpass';
ALTER USER supabase_auth_admin WITH PASSWORD :'pgpass';
ALTER USER supabase_storage_admin WITH PASSWORD :'pgpass';

-- The supabase/postgres base image pre-creates these auth helper functions
-- owned by postgres. GoTrue's own migration (00_init_auth_schema.up.sql)
-- tries to CREATE OR REPLACE them as supabase_auth_admin and fails with
-- 'must be owner of function' unless ownership is reassigned first.
ALTER FUNCTION auth.uid() OWNER TO supabase_auth_admin;
ALTER FUNCTION auth.role() OWNER TO supabase_auth_admin;
ALTER FUNCTION auth.email() OWNER TO supabase_auth_admin;

-- supabase_storage_admin connects directly (not via the authenticator/PostgREST
-- role-switching path) but the storage API still SETs ROLE service_role/anon/
-- authenticated per-request for RLS -- needs membership in those roles or every
-- Storage API request fails with 'permission denied to set role "service_role"'.
GRANT anon, authenticated, service_role TO supabase_storage_admin;
