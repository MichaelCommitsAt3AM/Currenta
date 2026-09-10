# Currenta landing page

The marketing site served at `currenta.tech` (Firebase Hosting, `currenta-prod`).
Vite multi-page build: `index.html` plus the three legal pages. Design system and
rationale in [PLAN.md](PLAN.md).

## Develop

```bash
npm install
npm run dev        # http://localhost:5174
```

## Build

```bash
npm run build      # -> landing/dist/
npm run preview    # serve the build on :4174
```

## Test

```bash
npm test           # Playwright smoke suite (uses system Google Chrome)
node test/shots.mjs # screenshot sweep into the scratch dir
```

## Content

All page copy and every headline stat live in [`src/content/copy.js`](src/content/copy.js).
Each number is sourced from `ARCHITECTURE.md` / `README.md` at the repo root — see PLAN.md §7.

## Legal pages

`privacy.html` / `terms.html` / `delete-account.html` are generated from the legacy
`public/*.html` (the content source of record) into the new shell:

```bash
node scripts/build-legal.mjs
```

Re-run this whenever the legacy legal copy changes, then commit the regenerated files.

## Waitlist

The form posts to `VITE_WAITLIST_ENDPOINT` (see `.env.example`). Until that's set it
fails closed with an error — it never fakes success. Endpoint options in PLAN.md §8.

## Deploy

Automatic on push to `main` via `.github/workflows/firebase-hosting-merge.yml`
(builds `landing/`, deploys `landing/dist` to Firebase Hosting `live`). PRs get a
preview channel via `firebase-hosting-pull-request.yml`.

Local: `npm install` once, then `firebase deploy --only hosting` from the repo root
(the `predeploy` hook runs `npm run build`).
