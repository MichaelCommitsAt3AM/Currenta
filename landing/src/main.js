import './styles/main.css';

import { ScrollTrigger } from './lib/gsap.js';
import { armReveals, combine } from './lib/motion.js';
import { initIcons } from './lib/lucide.js';
import { magneticAll } from './lib/magnetic.js';

import { mountNavbar } from './sections/navbar.js';
import { mountHero } from './sections/hero.js';
import { mountReveals } from './sections/reveals.js';
import { mountFeatures } from './sections/features.js';
import { mountPhilosophy } from './sections/philosophy.js';
import { mountPipeline } from './sections/pipeline.js';
import { mountWaitlist } from './sections/waitlist.js';

// Hide reveal targets before first paint so there's no flash of un-animated
// content (only when motion is allowed).
armReveals();

const cleanups = [];

function boot() {
  initIcons();

  cleanups.push(
    mountNavbar(),
    mountHero(),
    mountReveals(),
    mountFeatures(),
    mountPhilosophy(),
    mountPipeline(),
    mountWaitlist(),
    magneticAll(),
  );

  // Layout depends on fonts + the hero image; refresh triggers once they land.
  const refresh = () => ScrollTrigger.refresh();
  if (document.fonts?.ready) document.fonts.ready.then(refresh);
  window.addEventListener('load', refresh, { once: true });
}

if (document.readyState === 'loading') {
  document.addEventListener('DOMContentLoaded', boot, { once: true });
} else {
  boot();
}

if (import.meta.hot) {
  import.meta.hot.dispose(() => combine(cleanups)());
}
