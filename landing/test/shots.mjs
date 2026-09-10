import { chromium } from '@playwright/test';

const OUT = process.env.OUT || '/tmp/claude-1000/-home-fedora-AndroidStudioProjects-Currenta/58495c51-55ff-4995-a5b7-bdf036560c48/scratchpad';
const browser = await chromium.launch({ channel: 'chrome' });
const sections = ['hero', 'features', 'philosophy', 'pipeline', 'reading-modes', 'waitlist'];

for (const [name, width, height] of [['desktop', 1440, 900], ['mobile', 390, 844]]) {
  const page = await browser.newPage({ viewport: { width, height } });
  await page.goto('http://localhost:4174/', { waitUntil: 'networkidle' });
  await page.waitForTimeout(1600);
  await page.screenshot({ path: `${OUT}/shot-${name}-hero.png` });
  for (const id of sections.slice(1)) {
    await page.evaluate((s) => document.getElementById(s).scrollIntoView({ block: 'start' }), id);
    await page.waitForTimeout(2600);
    await page.screenshot({ path: `${OUT}/shot-${name}-${id}.png` });
  }
  // pipeline mid-stack
  await page.evaluate(() => window.scrollBy(0, window.innerHeight * 1.4));
  await page.waitForTimeout(1500);
  await page.screenshot({ path: `${OUT}/shot-${name}-pipeline-mid.png` });
  await page.close();
}
await browser.close();
console.log('done');
