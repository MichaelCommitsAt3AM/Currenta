import { inView } from '../lib/inView.js';
import { mountSummaryShuffler } from '../widgets/SummaryShuffler.js';
import { mountPipelineTypewriter } from '../widgets/PipelineTypewriter.js';
import { mountInterestTuner } from '../widgets/InterestTuner.js';

const FACTORIES = {
  'summary-shuffler': mountSummaryShuffler,
  'pipeline-typewriter': mountPipelineTypewriter,
  'interest-tuner': mountInterestTuner,
};

export function mountFeatures() {
  const hosts = [...document.querySelectorAll('[data-widget]')];
  const cleanups = [];

  hosts.forEach((host) => {
    const factory = FACTORIES[host.dataset.widget];
    if (!factory) return;
    const controls = factory(host);
    const stop = inView(host, {
      onEnter: controls.play,
      onLeave: controls.pause,
      threshold: 0.35,
    });
    cleanups.push(() => { stop(); controls.destroy(); });
  });

  return () => cleanups.forEach((fn) => fn());
}
