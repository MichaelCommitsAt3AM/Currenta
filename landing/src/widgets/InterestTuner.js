import { gsap } from '../lib/gsap.js';
import { prefersReducedMotion } from '../lib/motion.js';
import { interestTuner as data } from '../content/copy.js';

export function mountInterestTuner(host) {
  const chips = data.chips
    .map((c) => {
      const muted = c === data.muteTarget;
      return `<button type="button" tabindex="-1" data-chip="${c}"
        class="chip rounded-full border px-3 py-1.5 font-display text-[0.78rem] transition-colors duration-300
        ${muted ? 'border-charcoal/15 text-charcoal/30 line-through' : 'border-moss/30 bg-moss/10 text-moss'}">${c}</button>`;
    })
    .join('');

  const feed = (items) =>
    items
      .map(
        (t) => `<li class="truncate rounded-lg bg-cream px-3 py-2 text-[0.76rem] text-charcoal/70">${t}</li>`,
      )
      .join('');

  host.innerHTML = `
    <div class="relative h-full select-none">
      <div class="flex flex-wrap gap-1.5" data-chips>${chips}</div>
      <div class="mt-3 flex justify-end">
        <button type="button" tabindex="-1" data-save
          class="rounded-full bg-moss px-3.5 py-1.5 font-display text-[0.72rem] font-semibold text-cream">${data.saveLabel}</button>
      </div>
      <p class="mt-3 font-mono text-[0.6rem] uppercase tracking-[0.16em] text-charcoal/40">Feed preview</p>
      <ul class="mt-1.5 space-y-1.5" data-feed>${feed(data.feedBefore)}</ul>
      <svg data-cursor viewBox="0 0 24 24" width="20" height="20" class="pointer-events-none absolute left-0 top-0 z-20 drop-shadow">
        <path d="M4 2 L4 20 L9 15 L13 22 L16 20 L12 13 L19 13 Z" fill="#1A1A1A" stroke="#F2F0E9" stroke-width="1.2"/>
      </svg>
    </div>`;

  const chipsWrap = host.querySelector('[data-chips]');
  const target = host.querySelector(`[data-chip="${data.muteTarget}"]`);
  const save = host.querySelector('[data-save]');
  const feedEl = host.querySelector('[data-feed]');
  const cursor = host.querySelector('[data-cursor]');

  const centerOf = (el) => {
    const h = host.getBoundingClientRect();
    const r = el.getBoundingClientRect();
    return { x: r.left - h.left + r.width / 2 - 6, y: r.top - h.top + r.height / 2 - 4 };
  };

  const setMuted = (on) => {
    target.classList.toggle('line-through', on);
    target.classList.toggle('text-charcoal/30', on);
    target.classList.toggle('border-charcoal/15', on);
    target.classList.toggle('bg-moss/10', !on);
    target.classList.toggle('text-moss', !on);
    target.classList.toggle('border-moss/30', !on);
  };

  const swapFeed = (items) => {
    gsap.to(feedEl, {
      opacity: 0, y: 6, duration: 0.25,
      onComplete: () => {
        feedEl.innerHTML = feed(items);
        gsap.fromTo(feedEl, { opacity: 0, y: 6 }, { opacity: 1, y: 0, duration: 0.3 });
      },
    });
  };

  let tl = null;

  const staticEnd = () => {
    setMuted(true);
    feedEl.innerHTML = feed(data.feedAfter);
    cursor.style.display = 'none';
  };

  const play = () => {
    if (tl || prefersReducedMotion()) {
      if (prefersReducedMotion()) staticEnd();
      return;
    }
    setMuted(false);
    feedEl.innerHTML = feed(data.feedBefore);
    cursor.style.display = '';

    const start = centerOf(save);
    tl = gsap.timeline({ repeat: -1, repeatDelay: 2.4 });
    tl.set(cursor, { x: start.x, y: start.y, opacity: 0 })
      .to(cursor, { opacity: 1, duration: 0.3 }, 0.4)
      .to(cursor, { ...centerOf(target), duration: 0.9, ease: 'power2.inOut' })
      .to(cursor, { scale: 0.82, duration: 0.12, yoyo: true, repeat: 1 })
      .add(() => { setMuted(true); chipsWrap && gsap.fromTo(target, { scale: 0.9 }, { scale: 1, duration: 0.3, ease: 'back.out(2)' }); })
      .add(() => swapFeed(data.feedAfter), '+=0.1')
      .to(cursor, { ...centerOf(save), duration: 0.8, ease: 'power2.inOut' }, '+=0.5')
      .to(cursor, { scale: 0.82, duration: 0.12, yoyo: true, repeat: 1 })
      .add(() => gsap.fromTo(save, { scale: 0.92 }, { scale: 1, duration: 0.3, ease: 'back.out(2)' }))
      .to(cursor, { opacity: 0, duration: 0.4 }, '+=0.4')
      .add(() => { setMuted(false); swapFeed(data.feedBefore); }, '+=1.4');
  };

  const pause = () => {
    tl?.kill();
    tl = null;
  };

  const destroy = () => {
    pause();
    gsap.killTweensOf([cursor, feedEl, target, save]);
    host.replaceChildren();
  };

  return { play, pause, destroy };
}
