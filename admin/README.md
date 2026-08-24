# Currenta Admin Portal

React + TypeScript + Vite admin portal for manual news ingestion, a read-only SQL explorer, and usage analytics. Talks directly to the home server's backend and self-hosted Supabase stack (`dev-api.currenta.tech`) regardless of where this app itself is deployed — no local backend needed for dev.

## Develop

```bash
npm install
npm run dev       # http://localhost:3000
```

`.env.local` (gitignored) already has the dev Supabase anon key; copy `.env.example` if it's missing.

## Type generation

Request/response types (`src/types/api.ts`) are generated from the backend's live OpenAPI schema:

```bash
npm run gen:types
```

Re-run this after any change to `backend/api/admin.py`'s Pydantic models lands on `dev-api.currenta.tech`.

## Deploy

Deploys as static assets to Cloudflare Workers (`wrangler.toml`, project `hidden-paper-0d93`). Pushing to `main` builds and deploys automatically via `.github/workflows/deploy-admin.yml`. To deploy manually:

```bash
npm run build
npx wrangler deploy
```

The previous vanilla JS/HTML/CSS version of this portal (`admin-legacy/`) was deleted once this one reached full feature parity and was confirmed live — see git history if a rollback reference is ever needed.
