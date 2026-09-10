// Motion policy for the whole page.
//
// Every section exports `mount(root) -> cleanup()`. Sections that animate wrap
// their timelines in `whenMotion()` so the reduced-motion branch simply sets
// final states. `main.js` owns the list of cleanups and runs them on HMR dispose.

const mqReduce = window.matchMedia('(prefers-reduced-motion: reduce)');
const mqCoarse = window.matchMedia('(pointer: coarse)');

export const prefersReducedMotion = () => mqReduce.matches;
export const isCoarsePointer = () => mqCoarse.matches;

/**
 * Run `withMotion` when animation is allowed, otherwise `reduced` (which should
 * put elements in their final visual state). Returns a cleanup function.
 *
 * @param {(ctxTarget: Document) => (void | (() => void))} withMotion
 * @param {() => void} [reduced]
 * @returns {() => void}
 */
export function whenMotion(withMotion, reduced) {
  if (prefersReducedMotion()) {
    reduced?.();
    return () => {};
  }
  const cleanup = withMotion(document);
  return typeof cleanup === 'function' ? cleanup : () => {};
}

/** Toggle the class that hides `.js-reveal` elements until GSAP takes over. */
export function armReveals() {
  if (!prefersReducedMotion()) {
    document.documentElement.classList.add('motion-safe-hidden');
  }
}

/** Compose an array of (possibly undefined) cleanup fns into one. */
export function combine(cleanups) {
  return () => cleanups.forEach((fn) => {
    try { fn?.(); } catch { /* best effort on teardown */ }
  });
}
