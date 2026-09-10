import {
  createElement,
  ArrowUpRight,
  ArrowRight,
  Radio,
  Layers,
  Sparkles,
  ScanLine,
  MapPin,
  TrendingUp,
  Compass,
  ShieldCheck,
  Rss,
  CircleDot,
  Menu,
  X,
} from 'lucide';

const REGISTRY = {
  'arrow-up-right': ArrowUpRight,
  'arrow-right': ArrowRight,
  radio: Radio,
  layers: Layers,
  sparkles: Sparkles,
  'scan-line': ScanLine,
  'map-pin': MapPin,
  'trending-up': TrendingUp,
  compass: Compass,
  'shield-check': ShieldCheck,
  rss: Rss,
  'circle-dot': CircleDot,
  menu: Menu,
  x: X,
};

/** Replace every <i data-icon="name"> with an inline SVG. Idempotent. */
export function initIcons(root = document) {
  root.querySelectorAll('[data-icon]').forEach((host) => {
    const node = REGISTRY[host.dataset.icon];
    if (!node || host.dataset.iconDone) return;
    const svg = createElement(node);
    svg.setAttribute('aria-hidden', 'true');
    svg.setAttribute('width', host.dataset.iconSize || '18');
    svg.setAttribute('height', host.dataset.iconSize || '18');
    svg.setAttribute('stroke-width', host.dataset.iconStroke || '1.75');
    host.replaceChildren(svg);
    host.dataset.iconDone = '1';
  });
}
