# Currenta

AI-first news app: Flutter frontend, FastAPI backend (`backend/`), Supabase/Postgres+pgvector as the shared DB. See [README.md](README.md) for features/stack and [ARCHITECTURE.md](ARCHITECTURE.md) for the ingestion pipeline and recommendation logic.

## Structure

- `lib/` — Flutter app, feature-first (`lib/core/` for themes/config/network, `lib/features/` for Auth/News/Profile modules)
- `backend/` — FastAPI server (`backend/api/`), ingestion worker (`backend/worker.py`), AI/vector services (`backend/services/`)
- `supabase/` — DB migrations, schema, edge functions
- `admin/` — lightweight JS portal for DB exploration
- `test/` — Flutter unit/widget tests; backend tests live alongside their modules as `backend/test_*.py`

## Build & Test

- Flutter: `flutter analyze`, `flutter test`, `flutter run --dart-define-from-file=config/dev.json`
- Backend: run pytest from repo root, e.g. `python -m pytest backend/test_ingestion_pipeline.py -q` (this specific file is also the pre-deploy smoke check run by `scripts/deploy-gcp.sh`)
- Local full-stack dev: `bash scripts/dev-start.sh` (Docker + ngrok + optional Ollama), `scripts/dev-stop.sh` to tear down

## Infrastructure

- **Production**: GCP Cloud Run serves the live app. Deploy via `scripts/deploy-gcp.sh` (see `backend/GCP_MIGRATION.md`).
- **Supabase**: migrating off the hosted free tier (near its limit) onto the home server below, which now runs the actual Supabase stack itself (`db`/`auth`/`rest`/`storage` in `docker-compose.yml` — Postgres+pgvector, GoTrue Auth, PostgREST, file-backed Storage, trimmed of Realtime/Studio/Meta/edge-functions which this app doesn't use). Caddy routes `/auth/v1`, `/rest/v1`, `/storage/v1` to those services (see `Caddyfile`) so `supabase_flutter`/`supabase-py` need no code changes, only new `SUPABASE_URL`/keys. GCP Cloud Run prod points at this same home-server-hosted instance over the public tunnel — it is still the one shared DB for both prod and the home server, just no longer Supabase-cloud-hosted.
- **Home server ("laptop-server")**: an Ubuntu box (24.04→ actually 26.04 LTS, hostname `laptop-server`) used for (1) news ingestion (the `worker` service), (2) the self-hosted Supabase stack above, and (3) as the backend when running debug builds of the app during development/testing. It is **not** the developer's laptop despite the hostname — that name is legacy.
  - Reach it with `ssh laptop-server` (key-based auth, already configured, no password needed for SSH itself).
  - `sudo` on that box requires an interactive password — it is NOT passwordless. Any `apt install` / `systemctl` work needs the user to run it themselves or grant NOPASSWD explicitly.
  - The `docker-compose.yml` stack at repo root (`api`, `worker`, `redis`, `caddy`, `db`, `auth`, `rest`, `storage`) is designed to run persistently there (all services are `restart: unless-stopped`); deployed automatically on push to `main` via `.github/workflows/deploy-home-server.yml` (self-hosted runner on that box).
  - Public hostname exposure uses a Cloudflare Tunnel under the `currenta.tech` domain (Cloudflare-managed) — not ngrok, not router port-forwarding. The self-hosted Supabase stack reuses this same tunnel/hostname (path-routed via Caddy), no separate subdomain needed.
  - GCP Cloud Scheduler jobs that trigger ingestion/trending on Cloud Run (`currenta-orchestrate`, `currenta-trending`) should be paused once the home server takes over ingestion, to avoid double-ingestion against the shared DB.
- Local dev on an actual laptop still uses `scripts/dev-start.sh` (ngrok + optional Ollama) — separate from the home-server setup above. That script only brings up `api worker redis caddy`, not the self-hosted Supabase services, so laptop dev keeps pointing `SUPABASE_URL`/`DATABASE_URL` at whichever project (hosted or the home server's public URL) is configured in `.env`/`config/dev.json`.
