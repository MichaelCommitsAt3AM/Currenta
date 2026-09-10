import { gsap, ScrollTrigger } from '../lib/gsap.js';
import { whenMotion } from '../lib/motion.js';

export function mountHero() {
  const hero = document.querySelector('#hero');
  if (!hero) return () => {};

  const targets = [...hero.querySelectorAll('[data-reveal]')];
  const img = hero.querySelector('[data-hero-img]');
  const cue = hero.querySelector('[data-hero-cue]');

  return whenMotion(
    () => {
      const tl = gsap.timeline({ delay: 0.15 });
      tl.from(targets, { opacity: 0, y: 28, duration: 1, stagger: 0.09, ease: 'power3.out' });
      if (cue) tl.from(cue, { opacity: 0, duration: 0.6 }, '-=0.2');

      // Slow parallax drift on the background as the hero scrolls away.
      const parallax = gsap.to(img, {
        yPercent: 12,
        ease: 'none',
        scrollTrigger: { trigger: hero, start: 'top top', end: 'bottom top', scrub: true },
      });

      const cueLoop = cue
        ? gsap.to(cue, { y: 8, opacity: 0.15, repeat: -1, yoyo: true, duration: 1.4, ease: 'sine.inOut' })
        : null;

      return () => {
        tl.kill();
        parallax.scrollTrigger?.kill();
        parallax.kill();
        cueLoop?.kill();
      };
    },
    () => {
      gsap.set(targets, { opacity: 1, y: 0 });
    },
  );
}
