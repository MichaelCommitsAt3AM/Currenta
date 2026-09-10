# Currenta Landing Page — Ground-Up Redesign: Implementation Plan

Status: draft for review · Owner: web · Target: `currenta.tech` (Firebase Hosting, `currenta-prod`)

Design brief: the rewritten "High-End Editorial Tech / Newsroom Boutique" prompt (Moss/Clay/Cream/Charcoal,
Plus Jakarta Sans + Outfit + Cormorant Garamond + mono, GSAP-driven cinematic scroll, interactive micro-UI
dashboards). No pricing / subscription framing anywhere.

Confirmed decisions:
- **Build tooling:** new `landing/` Vite project, Tailwind, self-hosted fonts, optimized local images, GSAP/Lucide as npm deps.
- **CTA:** keep the waitlist (wired to a real endpoint this time); store badges stay "coming soon".
- **Legal pages:** restyle `privacy` / `terms` / `delete-account` to the new system (content text unchanged).

---

## 1. Goals / Non-goals

**Goals**
- Replace the current dark-purple static page (`public/index.html` + `style.css` + `script.js`) with the new design, built from `landing/`.
- Every headline claim on the page is backed by a real system fact (see §7). No invented metrics.
- Lighthouse ≥ 95 Performance / 100 Best-Practices / 100 SEO / ≥ 95 Accessibility on mobile.
- Full `prefers-reduced-motion` path — the page is legible and complete with zero animation.
- Keep the same public URLs working (`/`, `/privacy.html`, `/terms.html`, `/delete-account.html`) — Play Store console links to these.

**Non-goals**
- No CMS / blog / docs site. Single marketing page + 3 legal pages.
- No change to the app, backend, or `admin/`.
- No move off Firebase Hosting.

---

## 2. Current state (what we're replacing)

| Piece | Now | After |
|---|---|---|
| Source | Hand-written `public/*.html`, `public/style.css` (822 lines), `public/script.js` | Vite project in `landing/`, output `landing/dist/` |
| Deploy target | `firebase.json` → `hosting.public = "public"` | `hosting.public = "landing/dist"` + `predeploy` build |
| CI | `.github/workflows/firebase-hosting-{merge,pull-request}.yml` — checkout → deploy, no build | add Node setup + `npm ci && npm run build` in `landing/` before the deploy step |
| Waitlist | `script.js` fakes success, never sends the email anywhere | real submission (see §8) |
| Fonts | Outfit only, Google Fonts CDN | Plus Jakarta Sans + Outfit + Cormorant Garamond (italic) + JetBrains Mono, self-hosted via `@fontsource*` |
| Theme | `#0A0C14` bg, `#6C63FF` purple accent | Moss `#2E4036` / Clay `#CC5833` / Cream `#F2F0E9` / Charcoal `#1A1A1A` |

`.firebase/`, `firebase.json` project wiring, and the `FIREBASE_SERVICE_ACCOUNT_CURRENTA_PROD` secret are reused as-is.

---

## 3. Target project structure

```
landing/
  index.html                # main page, single document
  privacy.html              # MPA entries — restyled, share the design system
  terms.html
  delete-account.html
  vite.config.js            # MPA input map, imagetools, legacy-free (esbuild target 'es2020')
  tailwind.config.js        # design tokens (colors, radius scale, font families, tracking)
  postcss.config.js
  package.json
  PLAN.md                   # this file
  src/
    styles/
      main.css              # @tailwind layers + noise overlay + font-face wiring + base
    lib/
      gsap.js               # registers ScrollTrigger once; exports gsap, ScrollTrigger
      motion.js             # matchMedia (reduced-motion + breakpoints), context/cleanup helpers
      lucide.js             # tree-shaken icon registration
      inView.js             # IntersectionObserver helper for pausing offscreen widgets
    sections/
      navbar.js             # floating island + scroll morph
      hero.js               # staggered fade-up, bg parallax
      features.js           # mounts the 3 dashboard widgets
      philosophy.js         # split-text reveal + texture parallax
      pipeline.js           # sticky stacking archive (ScrollTrigger)
      readingModes.js       # "Three ways to read" (Trending / For You / Local)
      footer.js             # system-operational badge pulse
    widgets/
      SummaryShuffler.js    # Feature card 1
      PipelineTypewriter.js # Feature card 2
      InterestTuner.js      # Feature card 3 (mock-cursor)
      artifacts/            # per-pipeline-card SVG animations (hub / laser-grid / relevance-pulse)
    content/
      copy.js               # ALL page copy + the verified stat lines, one file
      images.js             # imported optimized image assets + srcset metadata
    assets/
      images/               # downloaded, optimized (AVIF/WebP) hero + texture images
      brand/                # logo lockups (from assets/icons/app_logo_new.png, re-exported clean)
  test/
    smoke.spec.ts           # Playwright: loads, no console errors, sections present, reduced-motion path
```

Old `public/` landing files are deleted at cutover (§9); `public/` itself may be removed once `firebase.json` no longer points at it.

---

## 4. Design-system implementation

**Tailwind tokens** (`tailwind.config.js`):
- `colors`: `moss`, `clay`, `cream`, `charcoal` (+ 2–3 tints each generated once, not ad hoc).
- `borderRadius`: `'2xl': '2rem'`, `'3xl': '3rem'`, `'4xl': '4rem'` (footer top).
- `fontFamily`: `sans` → Plus Jakarta Sans, `display` → Outfit, `serif` → Cormorant Garamond, `mono` → JetBrains Mono. Real fallback stacks on every one.
- `letterSpacing`: tight defaults for headings (`-0.02em` … `-0.04em` at display sizes).
- `fluid type`: use `clamp()` utilities for the hero (`text-[clamp(...)]`) — the "News without the / Noise." contrast is the signature moment.

**Global noise overlay** (`main.css`): fixed full-viewport `::before` (or a dedicated div) with an inline SVG `feTurbulence` data-URI at `opacity: 0.05`, `mix-blend-mode: overlay`, `pointer-events: none`, `z-index` above backgrounds / below content. One definition, reused.

**Radius system:** every card/container uses the `rounded-2xl`/`rounded-3xl` scale — no smaller radii.

**Motion primitives** (`motion.js`):
- Single `gsap.matchMedia()` instance. `(prefers-reduced-motion: no-preference)` gates every timeline; the reduced-motion branch sets final states with `gsap.set()` and wires no ScrollTriggers.
- Each section export is `mount(root) -> () => void` (cleanup). `gsap.context()` per section; cleanup calls `ctx.revert()` + disconnects observers + kills widget intervals.
- `ScrollTrigger.refresh()` fired once after `document.fonts.ready` and after hero/texture images `decode()`.
- Magnetic buttons: shared `magnetic(el)` util — `overflow-hidden` wrapper + sliding clay background layer on hover, subtle `scale(1.02)`; disabled under reduced-motion and on touch (`pointer: coarse`).

---

## 5. Section build spec

Order on page: Navbar · Hero · Features · Philosophy · Pipeline · Reading Modes · Footer.

### 5A. Navbar — "Floating Island"
Fixed, pill (`rounded-3xl`), centered, max-width. Two visual states cross-faded on scroll (`scrollY > 8`):
top = transparent bg + white text/border-none; scrolled = `bg-white/60 backdrop-blur-md` + moss text + `border-white/40`.
Links: Manifesto (→ Philosophy), How it works (→ Pipeline), Ways to read (→ Reading Modes), **Join waitlist** (magnetic clay button → waitlist). Mobile: real slide-down panel from the island (replace the current `alert()` stub).

### 5B. Hero — "News without the Noise"
- `100dvh`, background image (moody rain-lit city / long-exposure traffic — final pick per §6), Moss→Black gradient overlay, noise on top.
- Content bottom-left third. `h1`: "News without the" (`font-display` bold) + "Noise." (`font-serif italic`, massive).
- Mono sub-line pulling real numbers from `copy.js`: `184 sources · 65-word summaries · deduplicated · ranked for you`.
- Primary CTA: "Join the waitlist" (magnetic). Secondary: "Coming soon" + App Store / Play badges (non-link, muted) — reuse `assets/icons/google_play_badge.png`, add an App Store badge asset.
- GSAP: staggered fade-up (`y: 24, opacity: 0`, stagger `0.08`) on eyebrow → h1 lines → sub-line → CTAs. Background gets a slow `yPercent` parallax on scroll. Scroll cue at bottom.

### 5C. Features — "Precision Micro-UI Dashboard"
Three cards, each a working widget that **pauses when offscreen** (`inView.js`). Copy + labels from `copy.js`.

1. **Summary Shuffler** (`SummaryShuffler.js`) — 3 overlapping cream/white cards, `unshift(pop())` every 3s, spring transition `cubic-bezier(0.34, 1.56, 0.64, 1)`. Faces: mock headline + 65-word factual digest + source-count chip ("6 outlets → 1 story"). Labels cycle: **5Ws Summary · Dedup Cluster · Locality Match**.
2. **Pipeline Typewriter** (`PipelineTypewriter.js`) — live text feed, blinking clay cursor, pulsing "Live feed" dot. Messages (real pipeline stages): "Scanning 184 wire feeds…", "Blocking betting odds & live-blogs…", "Summarizing with Gemini…", "Embedding 1024-dim vector…", "Collapsing 6 sources into 1 story…".
3. **Interest Tuner** (`InterestTuner.js`) — taxonomy chip grid (Politics · Business · Tech · Science · Sport · Culture · Local), automated SVG cursor de-selects a chip (dim + strike, "muted"), clicks "Save", fades out; a small feed-preview list beside it re-orders to reflect the mute. Communicates "hard opt-out, not a nudge" (matches `user_muted_subcategories` behavior).

### 5D. Philosophy — "The Manifesto"
Charcoal section, parallaxing organic texture (creased newsprint / ink-on-fibre). GSAP split-text reveal (SplitType — MIT — not the paid GSAP SplitText) comparing:
"Old media asks: *What will make you click?*" vs "Currenta asks: *What do you actually need to know?*"
Serif italic on the questions. Lines reveal on scroll, word-by-word or line mask.

### 5E. Pipeline — "Sticky Stacking Archive"
Vertical stack of 3 full-viewport cards. ScrollTrigger pins the stack; as card N+1 enters, card N scales to `0.9`, `filter: blur(20px)`, `opacity: 0.5`. Cards:
1. **Discovery** — rotating radial hub, orbiting source nodes with connecting lines to center.
2. **Distillation** — laser-grid sweep over mock article text; redaction bars ("odds", "live-blog", "sponsored") dissolve as the beam passes, leaving a clean summary.
3. **Personalization** — pulsing relevance waveform / cosine beam between a "you" node and a drifting field of story points; nearest points light clay.

All three SVG animations live in `widgets/artifacts/`, each `mount/cleanup`, each reduced-motion-static.

### 5F. Reading Modes — "Three ways to read" (replaces the pricing grid)
3-card grid, **no prices, no tiers-by-cost, no "upgrade"**. Cards: **Trending · For You · Local**. Center "For You" pops: Moss background, Clay CTA ("Get the app" → waitlist for now). Each card: one editorial sentence + a mono stat line from real system config:
- Trending — "High-momentum stories in the categories you keep." · `20% of the feed · Google-Trends matched · decays each hour`
- For You — "Semantically matched to what you actually read, then re-ranked for freshness." · `70% of the feed · similarity × recency, 0.6 / 0.4`
- Local — "Your region's news, detected automatically." · `Geo-IP · dedicated local ingestion`

### 5G. Footer
Deep Charcoal, `rounded-t-4xl`. Columns: Manifesto, Ways to read, Privacy, Terms, Delete account data, `support@currenta.tech`. **"System operational"** badge with a pulsing green dot (static green under reduced-motion). Copyright line. No newsletter double-up (waitlist is the single capture).

---

## 6. Asset pipeline

**Images**
- Curate the 2–3 final photos (hero city scene, philosophy texture, any pipeline card bg). Verify each resolves and its Unsplash license (Unsplash License = free, no attribution required; still record photographer + URL in `landing/src/assets/images/CREDITS.md`).
- Download originals into the repo. Generate AVIF + WebP + JPEG fallback at responsive widths (640 / 1024 / 1600 / 2400) via `vite-imagetools` (or a one-off `sharp` script). No Unsplash hotlinking in production.
- `<picture>` with `srcset`/`sizes`; hero image gets `fetchpriority="high"` + preload; everything below the fold is `loading="lazy"` + `decoding="async"`.
- Target: hero image payload < 200 KB at mobile width.

**Fonts**
- `@fontsource-variable/plus-jakarta-sans`, `@fontsource-variable/outfit`, `@fontsource/cormorant-garamond` (400/500/600 + **italic**), `@fontsource-variable/jetbrains-mono`. Latin subset only.
- `font-display: swap`; `<link rel="preload">` for the two hero-critical faces (Jakarta 700, Cormorant italic 600).
- Self-hosted — drop the Google Fonts `<link>` and `preconnect`s entirely.

**Brand**
- Re-export a clean small logo lockup from `assets/icons/app_logo_new.png` (current `public/assets/icons/logo.png` is a 5.9 MB PNG — do not ship it). SVG lockup if available, else a ≤ 20 KB PNG + 2x.

**Icons**
- Lucide via npm, import only the icons used (~8–12), render to inline SVG at build or on mount. No full-library CDN.

---

## 7. Content source-of-truth

`src/content/copy.js` is the single place all copy + numbers live. Every stat traces to a repo fact — reviewer checks this table:

| Claim on page | Source | Value |
|---|---|---|
| "184 sources" / "180+ wire feeds" | `ARCHITECTURE.md` §Ingestion ("180+ RSS feeds and custom scrapers") | keep as "180+" unless we pin an exact count from the feeds config |
| "65-word summary (5Ws)" | `README.md`, `ARCHITECTURE.md` §3 | 65 words, factual, 5Ws |
| "1024-dim vector" | `ARCHITECTURE.md` §4 (`articles.embedding` / `dedup_embedding`, Voyage voyage-4-lite) | 1024 |
| "deduplicated at 0.75" | `ARCHITECTURE.md` §5 (`DUPLICATE_SIMILARITY_THRESHOLD`) | 0.75 cosine, event-key embedding |
| "70 / 20 / 10 feed mix" | `ARCHITECTURE.md` §Portfolio Interleave | Personalized 70 / Trending 20 / Discovery 10 |
| "similarity × recency, 0.6 / 0.4" | `ARCHITECTURE.md` (`PERSONALIZED_SIMILARITY_WEIGHT` / `_RECENCY_WEIGHT`) | 0.6 / 0.4 default |
| "48-hour window" | `ARCHITECTURE.md` (`FEED_WINDOW_HOURS`) | 48h |
| "trend score decays each hour" | `ARCHITECTURE.md` §Trend scoring (`TREND_SCORE_DECAY_FACTOR` 0.75) | half-life ≈ 2.4h |
| "disabling a category is a hard opt-out" | `ARCHITECTURE.md` §Recommendation; `[[project_client_taxonomy_now_bundled_asset]]` | hard filter, not de-prioritisation |
| "Geo-IP local news" | `README.md` §Key Features | automatic Geo-IP, dedicated local ingestion |
| Junk filtered: betting / sports previews / live-blogs | `README.md`, `ARCHITECTURE.md` §2 | deterministic regex gate |
| "System operational" badge | mirrors the real badge in the app footer (`CLAUDE.md`) | cosmetic, always shows operational unless we wire a real healthcheck (out of scope) |

If we can't source a number, it doesn't go on the page.

---

## 8. Waitlist wiring — BUILT

**Decision: FastAPI backend endpoint.** Best fit for this codebase — reuses the
existing asyncpg pool, slowapi rate limiter, structured logging, and the
home-server deploy pipeline. No new infra or vendor.

- **`POST /api/waitlist`** (`backend/api/waitlist.py`, registered in `backend/main.py`).
  Loose email validation + 254-char cap, honeypot handled client-side, `suspected_bot`
  flag persisted, IP stored only as `sha256(salt:ip)`. Idempotent: re-submitting an
  existing email returns `200 {new: false}`. Rate-limited `6/hour` per IP. Returns 503
  (not 500) when the DB/table is unavailable so the client shows a retry message.
- **Table `waitlist_signups`** — `supabase/migrations/20260910200000_add_waitlist_signups.sql`.
  Pure DDL. **Must be applied manually to the home server** (migrations aren't
  auto-run on deploy): `docker compose exec -T db psql -U postgres -d postgres -f - < supabase/migrations/20260910200000_add_waitlist_signups.sql`.
  RLS enabled with **no policies** on purpose — self-hosted PostgREST exposes `public`,
  and the signup list must never be REST-readable; the backend connects as table owner
  and bypasses RLS.
- **CORS**: `https://currenta.tech` + `https://www.currenta.tech` (and localhost dev
  ports) added to `ALLOWED_ORIGINS` default in `backend/main.py`.
- **Client** (`landing/src/sections/waitlist.js`): posts to
  `VITE_WAITLIST_ENDPOINT` (defaults to `https://dev-api.currenta.tech/api/waitlist`).
  Client-side email check, honeypot, double-submit lock, real fetch before any success
  state, 429 treated as success ("already on the list"), 422/5xx show errors.
- **Tests**: `backend/test_waitlist.py` (12, fake-pool unit tests) + 4 Playwright
  route-mocked tests in `landing/test/smoke.spec.ts`.

Sending the actual build-link emails to signups is out of scope — `notified_at` column
is there for whatever sends them later.

---

## 9. Build & deploy changes

1. `landing/vite.config.js`: MPA `rollupOptions.input` = { main, privacy, terms, deleteAccount }; `build.target: 'es2020'`; imagetools plugin; `base: '/'`.
2. `firebase.json`:
   - `hosting.public` → `"landing/dist"`.
   - Add `"predeploy": ["npm --prefix landing ci", "npm --prefix landing run build"]` (used for local `firebase deploy`; CI does it explicitly).
   - `"cleanUrls": true`, `"trailingSlash": false`.
   - `redirects`: none needed if we keep `.html` files; add `/privacy` → `/privacy.html` etc. only if we want clean URLs (cleanUrls handles it).
   - Cache headers: hashed assets (`/assets/**`) `max-age=31536000, immutable`; HTML `max-age=0, must-revalidate`.
   - Keep `ignore` list.
3. CI — both `firebase-hosting-merge.yml` and `firebase-hosting-pull-request.yml`: insert before the deploy step:
   ```yaml
   - uses: actions/setup-node@v4
     with: { node-version: 20, cache: npm, cache-dependency-path: landing/package-lock.json }
   - run: npm ci
     working-directory: landing
   - run: npm run build
     working-directory: landing
   ```
   The `FirebaseExtended/action-hosting-deploy@v0` step is unchanged (it just uploads what `firebase.json` points to). PR previews keep working (preview channel).
4. `.gitignore`: add `landing/dist/` and `landing/node_modules/`.
5. Custom domain: confirm `currenta.tech` (and `www`) are still attached to `currenta-prod` Hosting after cutover — no DNS change expected, just verify in the Firebase console.
6. **Cutover (end of Phase 7):** delete `public/index.html`, `public/style.css`, `public/script.js`, `public/assets/icons/logo.png`. The restyled legal pages now come from `landing/dist`. One PR, verified on a preview channel first.

---

## 10. Performance / A11y / SEO budget

- **Perf:** JS < 90 KB gz (GSAP core + ScrollTrigger ≈ 50 KB gz is the bulk; no React). CSS < 20 KB gz (Tailwind purged). LCP < 2.0s / CLS < 0.02 / INP < 200ms on a mid Android. Widgets use `requestAnimationFrame`, pause offscreen, and `will-change` only during active animation.
- **A11y:** semantic landmarks, one `h1`, logical heading order, `:focus-visible` rings in clay, ≥ 4.5:1 contrast (verify cream-on-moss, clay-on-cream — clay `#CC5833` on cream `#F2F0E9` is ~3.3:1, **fails for body text** → use clay only for large text / UI, moss/charcoal for body). Decorative SVG `aria-hidden`; the mock dashboards get an `aria-label` summary and are `aria-hidden` for their animated internals. Full keyboard path through nav + waitlist. Respect `prefers-reduced-motion` and `prefers-reduced-transparency` (fallback the glass navbar to solid).
- **SEO:** `<title>`, meta description, canonical, Open Graph + Twitter card (render a static 1200×630 share image), `og:image`, favicon set, `robots.txt`, `sitemap.xml`, JSON-LD `Organization` + `SoftwareApplication` (no `offers`/price). Pre-rendered HTML (Vite MPA is already static) — no JS needed for content to be indexable.

---

## 11. QA checklist (pre-cutover)

- [ ] Lighthouse mobile ≥ 95/100/100/95 on the Firebase preview URL.
- [ ] `prefers-reduced-motion: reduce` — page fully readable, no motion, all content in final position, no layout shift.
- [ ] Keyboard-only: nav, mobile menu, waitlist submit, all focusable, visible focus.
- [ ] Screen-reader pass (VoiceOver + NVDA) on hero, philosophy, waitlist.
- [ ] 320px / 768px / 1024px / 1440px / 2560px — no horizontal scroll; wide artifacts scroll inside their own container.
- [ ] Widgets pause when scrolled out of view (check with a perf trace).
- [ ] Waitlist: valid submit persists a row; invalid email blocked; double-click doesn't double-send; endpoint-down shows an error, not fake success.
- [ ] `/privacy.html`, `/terms.html`, `/delete-account.html` load, restyled, all internal links resolve.
- [ ] OG/Twitter preview renders (validator).
- [ ] No console errors/warnings. No 404s (fonts, images, favicon).
- [ ] Safari + Chrome + Firefox, iOS Safari + Android Chrome.
- [ ] `smoke.spec.ts` green in CI.

---

## 12. Phased delivery

Each phase is one PR, deployable, verified on a Firebase preview channel. The site doesn't go live until Phase 7.

| Phase | Scope | Exit criteria |
|---|---|---|
| **0 — Scaffold & pipeline** | `landing/` Vite MPA, Tailwind + tokens, fonts, Lucide, GSAP lib wiring, `motion.js`, CI build step, `firebase.json` pointed at `landing/dist` behind a preview channel. A trivial placeholder page. | Preview URL renders the placeholder; PR-preview CI works; prod still serves old `public/`. |
| **1 — Global shell** | Navbar island + scroll morph + mobile panel, footer + system badge, noise overlay, base layout, magnetic-button util, `copy.js` skeleton. | Nav + footer pixel-close to brief, reduced-motion clean. |
| **2 — Hero + Philosophy** | Hero (staggered reveal, bg parallax, CTA), Philosophy (split-text reveal, texture parallax), final image assets optimized. | Both sections match brief; LCP < 2s on preview. |
| **3 — Features dashboard** | `SummaryShuffler`, `PipelineTypewriter`, `InterestTuner` — all three interactive, offscreen-paused, reduced-motion-static. | Widgets "feel like real software"; no jank; correct labels/copy. |
| **4 — Pipeline stack** | Sticky stacking section + 3 SVG artifact animations. | Scroll scaling/blur/opacity per brief; pin release clean on mobile. |
| **5 — Reading modes + waitlist** | "Three ways to read" grid (no pricing), waitlist wired to real endpoint (§8), spam guards. | Real signup persists; center card treatment per brief. |
| **6 — Legal pages** | Restyle `privacy` / `terms` / `delete-account` with the shared system; content text verbatim from current pages. | Three pages consistent, links resolve, still Play-Store-valid. |
| **7 — Polish & cutover** | Perf/a11y/SEO pass, OG image, sitemap/robots/JSON-LD, full QA checklist, delete old `public/` landing files, point prod at `landing/dist`, verify custom domain. | QA checklist 100%; `currenta.tech` serves the new page; legal URLs unchanged. |

Rough size: Phase 0–1 small, 2 medium, **3 large** (the widgets are the real work), 4 medium, 5 medium (endpoint choice + spam), 6 small, 7 medium.

---

## 13. Risks / open questions

- **Clay-on-cream contrast** fails WCAG AA for body text (~3.3:1). Resolution: clay is an accent/large-text/UI color only; body copy is charcoal or moss. Confirm the brief's intent — the reference site likely does the same.
- **GSAP SplitText is a paid/Club plugin.** Use SplitType (MIT) or a hand-rolled line/word wrapper. Confirmed in plan.
- **Waitlist endpoint** — decide A/B/C in Phase 5. Recommend Firebase (A) to avoid coupling marketing uptime to `dev-api`.
- **Exact source count** — brief says "184", `ARCHITECTURE.md` says "180+". Either pin the number from the real feeds config or keep "180+".
- **Store badges** — if the Play listing goes live during the build, flip the "coming soon" block to real links (small change, isolated in `copy.js`).
- **`gsap` + `ScrollTrigger` pin + `100dvh`** on mobile Safari (URL bar resize) is historically finicky — budget test time in Phase 4; consider `svh`/`lvh` and `ScrollTrigger.normalizeScroll`.
- **Firebase preview channels** expire (default 7 days) — fine for review, don't rely on a preview URL as a long-lived stakeholder link.
- The reference prompt's Unsplash URLs are placeholders picked by theme; final image curation is a Phase 2 task with license capture.
