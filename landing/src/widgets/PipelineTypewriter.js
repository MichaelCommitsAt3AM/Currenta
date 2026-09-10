import { prefersReducedMotion } from '../lib/motion.js';
import { pipelineTypewriter as data } from '../content/copy.js';

const TYPE_MS = 26;
const HOLD_MS = 1400;

export function mountPipelineTypewriter(host) {
  host.innerHTML = `
    <div class="flex h-full flex-col gap-1.5 font-mono text-[0.78rem] leading-relaxed">
      <p class="text-charcoal/90"><span data-line></span><span class="helix-caret"></span></p>
      <div class="mt-1 flex-1 space-y-1.5 overflow-hidden" data-log></div>
    </div>`;

  const log = host.querySelector('[data-log]');
  const line = host.querySelector('[data-line]');
  let timeout = null;
  let i = 0;
  let running = false;

  const commit = (text) => {
    const p = document.createElement('p');
    p.className = 'text-charcoal/35';
    p.textContent = text;
    log.prepend(p); // newest just under the active line
    while (log.children.length > 5) log.removeChild(log.lastChild);
  };

  const typeLine = (text, done) => {
    let n = 0;
    const step = () => {
      if (!running) return;
      line.textContent = text.slice(0, n);
      if (n < text.length) {
        n += 1;
        timeout = setTimeout(step, TYPE_MS);
      } else {
        timeout = setTimeout(done, HOLD_MS);
      }
    };
    step();
  };

  const loop = () => {
    if (!running) return;
    const text = data.lines[i % data.lines.length];
    typeLine(text, () => {
      commit(text);
      line.textContent = '';
      i += 1;
      loop();
    });
  };

  const stop = () => {
    running = false;
    clearTimeout(timeout);
  };

  const play = () => {
    if (running) return;
    if (prefersReducedMotion()) {
      log.innerHTML = data.lines.map((l) => `<p class="text-charcoal/45">${l}</p>`).join('');
      line.textContent = '';
      host.querySelector('.helix-caret')?.remove();
      return;
    }
    running = true;
    loop();
  };

  const destroy = () => {
    stop();
    host.replaceChildren();
  };

  return { play, pause: stop, destroy };
}
