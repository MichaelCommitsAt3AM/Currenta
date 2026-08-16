# Currenta

AI-first news app: Flutter frontend, FastAPI backend (`backend/`), Supabase/Postgres+pgvector as the shared DB.

## Infrastructure

- **Production**: GCP Cloud Run serves the live app. Deploy via `scripts/deploy-gcp.sh` (see `backend/GCP_MIGRATION.md`).
- **Supabase**: shared Postgres DB — used by both GCP prod and the home server below. Not something to spin up/down.
- **Home server ("laptop-server")**: an Ubuntu box (24.04→ actually 26.04 LTS, hostname `laptop-server`) used for (1) news ingestion (the `worker` service — writes into the same Supabase DB as prod) and (2) as the backend when running debug builds of the app during development/testing. It is **not** the developer's laptop despite the hostname — that name is legacy.
  - Reach it with `ssh laptop-server` (key-based auth, already configured, no password needed for SSH itself).
  - `sudo` on that box requires an interactive password — it is NOT passwordless. Any `apt install` / `systemctl` work needs the user to run it themselves or grant NOPASSWD explicitly.
  - The `docker-compose.yml` stack at repo root (`api`, `worker`, `redis`, `caddy`) is designed to run persistently there (all services are `restart: unless-stopped`).
  - Public hostname exposure uses a Cloudflare Tunnel under the `currenta.tech` domain (Cloudflare-managed) — not ngrok, not router port-forwarding.
  - GCP Cloud Scheduler jobs that trigger ingestion/trending on Cloud Run (`currenta-orchestrate`, `currenta-trending`) should be paused once the home server takes over ingestion, to avoid double-ingestion against the shared Supabase DB.
- Local dev on an actual laptop still uses `scripts/dev-start.sh` (ngrok + optional Ollama) — separate from the home-server setup above.
