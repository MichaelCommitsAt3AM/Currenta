import { gsap } from '../lib/gsap.js';
import { prefersReducedMotion } from '../lib/motion.js';
import { summaryShuffler as data } from '../content/copy.js';

const SPRING = 'cubic-bezier(0.34, 1.56, 0.64, 1)';
const INTERVAL = 3200;

export function mountSummaryShuffler(host) {
  host.innerHTML = `
    <div class="relative h-full" data-deck>
      ${data.faces
        .map(
          (f) => `
        <article class="deck-card absolute inset-x-0 top-0 rounded-2xl border border-charcoal/10 bg-cream p-5 shadow-lg shadow-charcoal/5">
          <p class="font-mono text-[0.6rem] uppercase tracking-[0.2em] text-clay">${f.tag}</p>
          <h4 class="mt-2 font-display text-[0.95rem] font-semibold leading-snug">${f.headline}</h4>
          <p class="mt-2 line-clamp-4 text-[0.8rem] leading-relaxed text-charcoal/60">${f.body}</p>
          <span class="mt-3 inline-block rounded-full bg-moss/10 px-2.5 py-1 font-mono text-[0.6rem] text-moss">${f.chip}</span>
        </article>`,
        )
        .join('')}
    </div>`;

  const cards = [...host.querySelectorAll('.deck-card')];
  const order = cards.map((_, i) => i);
  let timer = null;

  const layout = (animate) => {
    order.forEach((cardIndex, depth) => {
      const el = cards[cardIndex];
      const props = {
        y: depth * 14,
        scale: 1 - depth * 0.05,
        opacity: depth > 2 ? 0 : 1 - depth * 0.15,
        zIndex: cards.length - depth,
      };
      if (animate && !prefersReducedMotion()) {
        gsap.to(el, { ...props, duration: 0.7, ease: SPRING });
      } else {
        gsap.set(el, props);
      }
    });
  };

  const advance = () => {
    order.push(order.shift());
    layout(true);
  };

  layout(false);

  const play = () => {
    if (timer || prefersReducedMotion()) return;
    timer = setInterval(advance, INTERVAL);
  };
  const pause = () => {
    clearInterval(timer);
    timer = null;
  };
  const destroy = () => {
    pause();
    gsap.killTweensOf(cards);
    host.replaceChildren();
  };

  return { play, pause, destroy };
}
