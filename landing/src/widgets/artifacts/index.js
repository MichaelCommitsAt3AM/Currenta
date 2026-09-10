import { gsap } from '../../lib/gsap.js';
import { prefersReducedMotion } from '../../lib/motion.js';

const SVG = 'http://www.w3.org/2000/svg';
const el = (name, attrs = {}) => {
  const node = document.createElementNS(SVG, name);
  for (const [k, v] of Object.entries(attrs)) node.setAttribute(k, v);
  return node;
};
const frame = (host) => {
  const svg = el('svg', { viewBox: '0 0 320 320', class: 'h-full w-full', fill: 'none' });
  host.replaceChildren(svg);
  return svg;
};

/* ----------------------------- 01 · hub ----------------------------- */
function hub(host) {
  const svg = frame(host);
  const g = el('g', { transform: 'translate(160 160)' });
  svg.appendChild(g);

  [70, 110, 145].forEach((r) => g.appendChild(el('circle', { r, stroke: '#2E4036', 'stroke-opacity': '0.15' })));
  g.appendChild(el('circle', { r: 6, fill: '#CC5833' }));

  const nodes = [];
  const N = 11;
  for (let i = 0; i < N; i += 1) {
    const a = (i / N) * Math.PI * 2;
    const r = [70, 110, 145][i % 3];
    const x = Math.cos(a) * r;
    const y = Math.sin(a) * r;
    g.appendChild(el('line', { x1: 0, y1: 0, x2: x, y2: y, stroke: '#2E4036', 'stroke-opacity': '0.12' }));
    const dot = el('circle', { cx: x, cy: y, r: 3.5, fill: '#2E4036', 'fill-opacity': '0.6' });
    g.appendChild(dot);
    nodes.push(dot);
  }

  if (prefersReducedMotion()) return noop();
  const spin = gsap.to(g, { rotation: 360, transformOrigin: 'center', duration: 46, repeat: -1, ease: 'none' });
  const twinkle = gsap.to(nodes, {
    fillOpacity: 1, fill: '#CC5833', duration: 1.2, stagger: { each: 0.4, repeat: -1, yoyo: true }, ease: 'sine.inOut',
  });
  return control([spin, twinkle], host);
}

/* -------------------------- 02 · laser grid ------------------------- */
function laser(host) {
  const svg = frame(host);
  const rows = 9;
  const bars = [];
  const redactions = [];
  for (let i = 0; i < rows; i += 1) {
    const y = 34 + i * 28;
    const w = 150 + ((i * 47) % 120);
    svg.appendChild(el('rect', { x: 26, y, width: w, height: 8, rx: 4, fill: '#2E4036', 'fill-opacity': '0.14' }));
    if ([1, 3, 6].includes(i)) {
      const red = el('rect', { x: 26 + w - 60, y: y - 3, width: 66, height: 14, rx: 3, fill: '#CC5833', 'fill-opacity': '0.8' });
      svg.appendChild(red);
      redactions.push(red);
    }
    bars.push(y);
  }
  const scan = el('line', { x1: 20, x2: 300, y1: 24, y2: 24, stroke: '#CC5833', 'stroke-width': 2 });
  const glow = el('rect', { x: 20, y: 12, width: 280, height: 24, fill: '#CC5833', 'fill-opacity': '0.12' });
  svg.append(glow, scan);

  if (prefersReducedMotion()) {
    redactions.forEach((r) => r.setAttribute('fill-opacity', '0'));
    scan.setAttribute('opacity', '0');
    glow.setAttribute('opacity', '0');
    return noop();
  }

  const tl = gsap.timeline({ repeat: -1, repeatDelay: 1.1 });
  tl.set([scan, glow], { attr: { y1: 24, y2: 24, y: 12 } })
    .set(redactions, { attr: { 'fill-opacity': 0.8 } })
    .to({}, { duration: 0.4 })
    .to([scan], { attr: { y1: 288, y2: 288 }, duration: 2.6, ease: 'none' }, 0.4)
    .to([glow], { attr: { y: 276 }, duration: 2.6, ease: 'none' }, 0.4);
  redactions.forEach((r, i) => tl.to(r, { attr: { 'fill-opacity': 0 }, duration: 0.3 }, 0.7 + i * 0.85));
  return control([tl], host);
}

/* ------------------------ 03 · relevance pulse --------------------- */
function pulse(host) {
  const svg = frame(host);
  const you = el('circle', { cx: 40, cy: 160, r: 7, fill: '#CC5833' });
  svg.appendChild(el('text', { x: 40, y: 186, fill: '#2E4036', 'font-size': 11, 'text-anchor': 'middle', 'font-family': 'monospace' })).textContent = 'you';
  svg.appendChild(you);

  const stories = [];
  for (let i = 0; i < 16; i += 1) {
    const x = 120 + ((i * 53) % 170);
    const y = 40 + ((i * 89) % 240);
    const dot = el('circle', { cx: x, cy: y, r: 3.5, fill: '#2E4036', 'fill-opacity': '0.35' });
    svg.appendChild(dot);
    stories.push({ dot, near: (x - 40) ** 2 + (y - 160) ** 2 < 20000 });
  }

  const wave = el('path', { d: 'M40 160 q 60 -40 120 0 t 120 0', stroke: '#CC5833', 'stroke-width': 2, 'stroke-opacity': 0.5 });
  svg.appendChild(wave);

  if (prefersReducedMotion()) {
    stories.filter((s) => s.near).forEach((s) => { s.dot.setAttribute('fill', '#CC5833'); s.dot.setAttribute('fill-opacity', '1'); });
    wave.setAttribute('opacity', '0');
    return noop();
  }

  const ring = el('circle', { cx: 40, cy: 160, r: 8, stroke: '#CC5833', 'stroke-width': 1.5, fill: 'none' });
  svg.appendChild(ring);
  const tl = gsap.timeline({ repeat: -1 });
  tl.fromTo(ring, { attr: { r: 8 }, opacity: 0.8 }, { attr: { r: 230 }, opacity: 0, duration: 2.6, ease: 'power1.out' })
    .to(stories.filter((s) => s.near).map((s) => s.dot), {
      fill: '#CC5833', fillOpacity: 1, duration: 0.4, stagger: 0.06,
    }, 0.9)
    .to(stories.filter((s) => s.near).map((s) => s.dot), {
      fill: '#2E4036', fillOpacity: 0.35, duration: 0.5,
    }, 2.2);
  const waveLoop = gsap.to(wave, { attr: { d: 'M40 160 q 60 40 120 0 t 120 0' }, duration: 1.6, yoyo: true, repeat: -1, ease: 'sine.inOut' });
  return control([tl, waveLoop], host);
}

/* ----------------------------- helpers ---------------------------- */
function control(tweens, host) {
  return {
    play: () => tweens.forEach((t) => t.play()),
    pause: () => tweens.forEach((t) => t.pause()),
    destroy: () => { tweens.forEach((t) => t.kill()); host.replaceChildren(); },
  };
}
function noop() {
  return { play() {}, pause() {}, destroy() {} };
}

const ARTIFACTS = { hub, laser, pulse };

export function mountArtifact(name, host) {
  return (ARTIFACTS[name] || noop)(host);
}
