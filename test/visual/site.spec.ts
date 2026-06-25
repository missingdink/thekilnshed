import { test, expect } from '@playwright/test';

const PAGES = [
  { path: '/', name: 'home' },
  { path: '/404.html', name: 'not-found' },
];

const VIEWPORTS = [
  { name: 'desktop', width: 1280, height: 800 },
  { name: 'mobile', width: 375, height: 667 },
];

for (const page of PAGES) {
  for (const vp of VIEWPORTS) {
    test(`${page.name} at ${vp.name}`, async ({ page: pw, browserName }) => {
      await pw.setViewportSize({ width: vp.width, height: vp.height });
      await pw.goto(page.path, { waitUntil: 'networkidle' });
      await expect(pw).toHaveScreenshot(`${page.name}-${vp.name}-${browserName}.png`);
    });
  }
}
