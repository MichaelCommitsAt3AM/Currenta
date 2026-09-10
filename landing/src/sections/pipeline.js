import { gsap, ScrollTrigger } from '../lib/gsap.js';
import { whenMotion } from '../lib/motion.js';
import { inView } from '../lib/inView.js';
import { mountArtifact } from '../widgets/artifacts/index.js';

export function mountPipeline() {
  const stack = document.querySelector('[data-pipeline-stack]');
  if (!stack) return () => {};

  const cards = [...stack.querySelectorAll('[data-pipeline-card]')];
  const artifactCleanups = [];

  // Artifacts run regardless of motion pref (they're modest), but pause off-screen.
  cards.forEach((card) => {
    const host = card.querySelector('[data-artifact]');
    if (!host) return;
    const controls = mountArtifact(host.dataset.artifact, host);
    const stop = inView(card, { onEnter: controls.play, onLeave: controls.pause, threshold: 0.2 });
    artifactCleanups.push(() => { stop(); controls.destroy(); });
  });

  const motionCleanup = whenMotion(() => {
    const triggers = [];
    cards.forEach((card, i) => {
      const next = cards[i + 1];
      if (!next) return;
      const st = gsap.to(card.firstElementChild, {
        scale: 0.9,
        filter: 'blur(20px)',
        opacity: 0.5,
        ease: 'none',
        scrollTrigger: { trigger: next, start: 'top bottom', end: 'top top', scrub: true },
      });
      triggers.push(st);
    });
    return () => triggers.forEach((t) => { t.scrollTrigger?.kill(); t.kill(); });
  });

  return () => {
    artifactCleanups.forEach((fn) => fn());
    motionCleanup();
  };
}
