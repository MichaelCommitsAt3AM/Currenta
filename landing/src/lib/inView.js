/**
 * Call `onEnter` / `onLeave` as `el` crosses the viewport. Used to pause the
 * dashboard widgets when they're off-screen (battery + main-thread budget).
 *
 * @returns {() => void} disconnect
 */
export function inView(el, { onEnter, onLeave, threshold = 0.25 } = {}) {
  if (typeof IntersectionObserver === 'undefined') {
    onEnter?.();
    return () => {};
  }
  const io = new IntersectionObserver(
    (entries) => {
      for (const entry of entries) {
        if (entry.isIntersecting) onEnter?.();
        else onLeave?.();
      }
    },
    { threshold },
  );
  io.observe(el);
  return () => io.disconnect();
}
