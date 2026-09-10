import { gsap, ScrollTrigger } from '../lib/gsap.js';
import { whenMotion } from '../lib/motion.js';

// Generic scroll-in for every [data-reveal] that isn't owned by the hero
// (hero runs its own intro timeline on load).
export function mountReveals() {
  return whenMotion(
    () => {
      const targets = gsap.utils.toArray('[data-reveal]').filter((el) => !el.closest('#hero'));
      gsap.set(targets, { opacity: 0, y: 26 });

      const batch = ScrollTrigger.batch(targets, {
        start: 'top 88%',
        onEnter: (els) =>
          gsap.to(els, { opacity: 1, y: 0, duration: 0.8, stagger: 0.08, overwrite: true }),
      });

      // Reveal targets are hidden via .motion-safe-hidden; now GSAP owns them.
      document.documentElement.classList.remove('motion-safe-hidden');

      return () => batch.forEach((st) => st.kill());
    },
    () => {
      document.documentElement.classList.remove('motion-safe-hidden');
    },
  );
}
