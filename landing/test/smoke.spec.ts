import { test, expect } from '@playwright/test';

const PAGES = ['/', '/privacy.html', '/terms.html', '/delete-account.html'];

for (const path of PAGES) {
  test(`${path} loads without console errors`, async ({ page }) => {
    const errors: string[] = [];
    page.on('console', (m) => m.type() === 'error' && errors.push(m.text()));
    page.on('pageerror', (e) => errors.push(String(e)));

    const res = await page.goto(path, { waitUntil: 'networkidle' });
    expect(res?.status()).toBeLessThan(400);
    await expect(page.locator('h1')).toBeVisible();
    expect(errors, errors.join('\n')).toEqual([]);
  });
}

test('landing has all major sections', async ({ page }) => {
  await page.goto('/');
  for (const id of ['hero', 'features', 'philosophy', 'pipeline', 'reading-modes', 'waitlist']) {
    await expect(page.locator(`#${id}`)).toHaveCount(1);
  }
  // widgets mount
  await expect(page.locator('[data-widget="summary-shuffler"] .deck-card').first()).toBeVisible();
  await expect(page.locator('[data-widget="pipeline-typewriter"] [data-line]')).toHaveCount(1);
  await expect(page.locator('[data-widget="interest-tuner"] [data-chip]').first()).toBeVisible();
});

test('pipeline typewriter types once scrolled into view', async ({ page }) => {
  await page.goto('/');
  await page.locator('#features').scrollIntoViewIfNeeded();
  await expect(page.locator('[data-widget="pipeline-typewriter"] [data-line]')).not.toHaveText('', {
    timeout: 4000,
  });
});

test('waitlist rejects an invalid email client-side (no network call)', async ({ page }) => {
  let called = false;
  await page.route('**/api/waitlist', (r) => { called = true; r.fulfill({ status: 200, body: '{}' }); });
  await page.goto('/');
  await page.locator('#waitlist-email').fill('not-an-email');
  await page.locator('[data-waitlist] button[type="submit"]').click();
  await expect(page.locator('[data-waitlist-message]')).toContainText('email address');
  expect(called).toBe(false);
});

test('waitlist posts a valid email and confirms', async ({ page }) => {
  const seen: any[] = [];
  await page.route('**/api/waitlist', async (route) => {
    seen.push(route.request().postDataJSON());
    await route.fulfill({ status: 200, contentType: 'application/json', body: JSON.stringify({ status: 'ok', new: true }) });
  });
  await page.goto('/');
  await page.locator('#waitlist-email').fill('reader@example.com');
  await page.locator('[data-waitlist] button[type="submit"]').click();
  await expect(page.locator('[data-waitlist-message]')).toContainText('on the list');
  expect(seen).toHaveLength(1);
  expect(seen[0].email).toBe('reader@example.com');
  expect(seen[0]).toHaveProperty('suspected_bot');
});

test('waitlist treats 429 as success', async ({ page }) => {
  await page.route('**/api/waitlist', (r) => r.fulfill({ status: 429, body: 'Too Many Requests' }));
  await page.goto('/');
  await page.locator('#waitlist-email').fill('reader@example.com');
  await page.locator('[data-waitlist] button[type="submit"]').click();
  await expect(page.locator('[data-waitlist-message]')).toContainText('on the list');
});

test('waitlist shows an error when the endpoint fails', async ({ page }) => {
  await page.route('**/api/waitlist', (r) => r.fulfill({ status: 500, body: 'boom' }));
  await page.goto('/');
  await page.locator('#waitlist-email').fill('reader@example.com');
  await page.locator('[data-waitlist] button[type="submit"]').click();
  await expect(page.locator('[data-waitlist-message]')).toContainText('went wrong');
});

test('reduced-motion: hero content is visible without animation', async ({ page }) => {
  await page.emulateMedia({ reducedMotion: 'reduce' });
  await page.goto('/');
  await expect(page.locator('#hero h1')).toBeVisible();
  await expect(page.locator('#hero p').first()).toBeVisible();
});

test('mobile nav toggle opens and closes the panel', async ({ page }) => {
  await page.setViewportSize({ width: 390, height: 844 });
  await page.goto('/');
  const panel = page.locator('[data-nav-panel]');
  await expect(panel).toBeHidden();
  await page.locator('[data-nav-toggle]').click();
  await expect(panel).toBeVisible();
  await page.locator('[data-nav-panel] a').first().click();
  await expect(panel).toBeHidden();
});
