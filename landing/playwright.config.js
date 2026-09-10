import { defineConfig, devices } from '@playwright/test';

// Uses the system Google Chrome (Playwright's bundled browsers aren't downloadable
// in this environment). CI can switch to bundled chromium.
export default defineConfig({
  testDir: './test',
  fullyParallel: true,
  reporter: 'list',
  use: {
    baseURL: 'http://localhost:4174',
    channel: 'chrome',
  },
  webServer: {
    command: 'npm run preview',
    url: 'http://localhost:4174',
    reuseExistingServer: !process.env.CI,
    timeout: 60_000,
  },
  projects: [
    { name: 'desktop', use: { ...devices['Desktop Chrome'], channel: 'chrome' } },
    { name: 'mobile', use: { ...devices['Pixel 7'], channel: 'chrome' } },
  ],
});
