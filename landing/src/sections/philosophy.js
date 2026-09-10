import SplitType from 'split-type';
import { gsap, ScrollTrigger } from '../lib/gsap.js';
import { whenMotion } from '../lib/motion.js';

export function mountPhilosophy() {
  const section = document.querySelector('#philosophy');
  if (!section) return () => {};

  const lines = [...section.querySelectorAll('[data-split]')];
  const texture = section.querySelector('[data-philosophy-img]');

  return whenMotion(
    () => {
      const splits = lines.map((el) => new SplitType(el, { types: 'words', tagName: 'span' }));
      splits.forEach((s) => gsap.set(s.words, { display: 'inline-block' }));

      const tl = gsap.timeline({
        scrollTrigger: { trigger: section, start: 'top 65%', end: 'top 20%', scrub: 0.6 },
      });
      splits.forEach((s, i) => {
        tl.from(s.words, { opacity: 0.12, y: 16, filter: 'blur(6px)', stagger: 0.04, duration: 0.5 }, i * 0.25);
      });

      const parallax = texture
        ? gsap.fromTo(
            texture,
            { yPercent: -8 },
            { yPercent: 8, ease: 'none', scrollTrigger: { trigger: section, start: 'top bottom', end: 'bottom top', scrub: true } },
          )
        : null;

      return () => {
        tl.scrollTrigger?.kill();
        tl.kill();
        parallax?.scrollTrigger?.kill();
        parallax?.kill();
        splits.forEach((s) => s.revert());
      };
    },
    () => {},
  );
}
