// Ports the three legal pages from the legacy `public/*.html` into the new
// design shell. Content text is copied verbatim; only the surrounding markup,
// inline styles, and asset links change. Re-run when the legacy pages change.
//
//   node scripts/build-legal.mjs
//
import { readFileSync, writeFileSync } from 'node:fs';
import { resolve, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';

const here = dirname(fileURLToPath(import.meta.url));
const legacyDir = resolve(here, '../../public');
const outDir = resolve(here, '..');

const PAGES = [
  { src: 'privacy.html', out: 'privacy.html', title: 'Privacy policy', desc: 'How Currenta collects, uses, and protects your data.' },
  { src: 'terms.html', out: 'terms.html', title: 'Terms of service', desc: 'The terms governing your use of Currenta.' },
  { src: 'delete-account.html', out: 'delete-account.html', title: 'Delete account data', desc: 'How to delete your Currenta account and associated data.' },
];

const shell = ({ title, desc, body }) => `<!doctype html>
<html lang="en">
  <head>
    <meta charset="UTF-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <title>${title} — Currenta</title>
    <meta name="description" content="${desc}" />
    <link rel="canonical" href="https://currenta.tech/${title === 'Privacy policy' ? 'privacy' : title === 'Terms of service' ? 'terms' : 'delete-account'}.html" />
    <meta name="theme-color" content="#2E4036" />
    <link rel="icon" href="/favicon.ico" sizes="any" />
    <link rel="icon" type="image/png" href="/favicon-32.png" sizes="32x32" />
    <link rel="apple-touch-icon" href="/apple-touch-icon.png" />
    <meta name="robots" content="index,follow" />
    <script type="module" src="/src/legal.js"></script>
  </head>
  <body class="min-h-screen bg-cream text-charcoal">
    <div class="grain-layer" aria-hidden="true"></div>

    <header class="border-b border-charcoal/10">
      <div class="shell flex items-center justify-between py-5">
        <a href="/" class="flex items-center gap-2.5">
          <img src="./src/assets/brand/logo-96.png" width="26" height="26" alt="" class="h-6 w-6 rounded-lg" />
          <span class="font-display text-lg font-bold tracking-tighter2">Currenta</span>
        </a>
        <a href="/" class="font-display text-sm tracking-tight text-charcoal/60 hover:text-charcoal">← Back home</a>
      </div>
    </header>

    <main class="shell max-w-3xl py-16 sm:py-24">
      <article class="prose-legal">
${body}
    </article>
    </main>

    <footer class="rounded-t-4xl bg-charcoal px-6 py-14 text-cream">
      <div class="shell max-w-3xl">
        <nav class="flex flex-wrap gap-x-8 gap-y-2 text-sm text-cream/60" aria-label="Footer">
          <a href="/privacy.html" class="hover:text-cream">Privacy policy</a>
          <a href="/terms.html" class="hover:text-cream">Terms of service</a>
          <a href="/delete-account.html" class="hover:text-cream">Delete account data</a>
          <a href="mailto:support@currenta.tech" class="hover:text-cream">support@currenta.tech</a>
        </nav>
        <p class="mt-6 font-mono text-xs text-cream/40">© 2026 Currenta. All rights reserved.</p>
      </div>
    </footer>
  </body>
</html>
`;

for (const page of PAGES) {
  const raw = readFileSync(resolve(legacyDir, page.src), 'utf8');
  const match = raw.match(/<div class="legal-content">([\s\S]*?)<\/div>\s*<\/div>\s*<footer>/);
  if (!match) throw new Error(`could not extract content from ${page.src}`);

  let body = match[1]
    .replace(/\s*style="[^"]*"/g, '') // drop all inline styles
    .replace(/class="legal-header"/g, 'class="legal-header"')
    .trim();

  writeFileSync(resolve(outDir, page.out), shell({ title: page.title, desc: page.desc, body }));
  console.log(`wrote ${page.out} (${body.length} chars of content)`);
}
