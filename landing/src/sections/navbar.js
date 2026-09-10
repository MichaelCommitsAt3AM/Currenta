import { gsap } from '../lib/gsap.js';

// Floating island: transparent + cream text over the hero, glass + moss text once
// the page scrolls. Plus a real mobile panel (replacing the old alert() stub).
export function mountNavbar() {
  const header = document.querySelector('[data-navbar]');
  if (!header) return () => {};

  const island = header.querySelector('.island');
  const toggle = header.querySelector('[data-nav-toggle]');
  const panel = header.querySelector('[data-nav-panel]');
  const iconMenu = toggle?.querySelector('[data-nav-icon="menu"]');
  const iconClose = toggle?.querySelector('[data-nav-icon="close"]');

  const SCROLLED = ['text-moss', 'bg-white/65', 'backdrop-blur-md', '!border-white/40', 'shadow-lg', 'shadow-charcoal/5'];

  let scrolled = null;
  const onScroll = () => {
    const next = window.scrollY > 8;
    if (next === scrolled) return;
    scrolled = next;
    island.classList.toggle('text-cream', !next);
    SCROLLED.forEach((c) => island.classList.toggle(c, next));
  };
  onScroll();
  window.addEventListener('scroll', onScroll, { passive: true });

  // --- mobile panel ---
  let open = false;
  const setOpen = (next) => {
    open = next;
    toggle.setAttribute('aria-expanded', String(next));
    toggle.setAttribute('aria-label', next ? 'Close menu' : 'Open menu');
    iconMenu?.toggleAttribute('hidden', next);
    iconClose?.toggleAttribute('hidden', !next);
    if (next) {
      panel.hidden = false;
      gsap.fromTo(panel, { opacity: 0, y: -8, scaleY: 0.96 }, { opacity: 1, y: 0, scaleY: 1, duration: 0.28, ease: 'power2.out' });
    } else {
      gsap.to(panel, { opacity: 0, y: -8, duration: 0.18, ease: 'power2.in', onComplete: () => { panel.hidden = true; } });
    }
  };

  const onToggle = () => setOpen(!open);
  const onPanelClick = (e) => { if (e.target.closest('a')) setOpen(false); };
  const onKey = (e) => { if (e.key === 'Escape' && open) setOpen(false); };
  const onResize = () => { if (open && window.innerWidth >= 768) setOpen(false); };

  toggle.addEventListener('click', onToggle);
  panel.addEventListener('click', onPanelClick);
  document.addEventListener('keydown', onKey);
  window.addEventListener('resize', onResize);

  return () => {
    window.removeEventListener('scroll', onScroll);
    window.removeEventListener('resize', onResize);
    toggle.removeEventListener('click', onToggle);
    panel.removeEventListener('click', onPanelClick);
    document.removeEventListener('keydown', onKey);
  };
}
