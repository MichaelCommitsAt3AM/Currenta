import { gsap } from './gsap.js';
import { prefersReducedMotion, isCoarsePointer } from './motion.js';

/**
 * Subtle magnetic pull toward the cursor on pointer-fine devices. The colour
 * transition itself is CSS (`.btn::after`); this only adds the weighted drift.
 *
 * @param {HTMLElement} el
 * @returns {() => void} cleanup
 */
export function magnetic(el, strength = 0.28) {
  if (prefersReducedMotion() || isCoarsePointer()) return () => {};

  const quickX = gsap.quickTo(el, 'x', { duration: 0.5, ease: 'power3.out' });
  const quickY = gsap.quickTo(el, 'y', { duration: 0.5, ease: 'power3.out' });

  const onMove = (e) => {
    const r = el.getBoundingClientRect();
    quickX((e.clientX - (r.left + r.width / 2)) * strength);
    quickY((e.clientY - (r.top + r.height / 2)) * strength);
  };
  const reset = () => { quickX(0); quickY(0); };

  el.addEventListener('pointermove', onMove);
  el.addEventListener('pointerleave', reset);
  return () => {
    el.removeEventListener('pointermove', onMove);
    el.removeEventListener('pointerleave', reset);
    gsap.set(el, { x: 0, y: 0 });
  };
}

export function magneticAll(root = document) {
  const cleanups = [];
  root.querySelectorAll('[data-magnetic]').forEach((el) => cleanups.push(magnetic(el)));
  return () => cleanups.forEach((fn) => fn());
}
