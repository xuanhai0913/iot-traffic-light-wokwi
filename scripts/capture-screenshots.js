const path = require('path');
const fs = require('fs');

let chromium;
try {
  ({ chromium } = require('playwright'));
} catch (error) {
  throw new Error('Playwright is required. Install it with: npm install --save-dev playwright');
}

const APP_URL = process.env.APP_URL || 'http://localhost:8080';
const OUT_DIR = process.env.E2E_OUT_DIR
  ? path.resolve(process.env.E2E_OUT_DIR)
  : path.resolve(__dirname, '..', 'assets', 'e2e');
const VIEWPORT = { width: 1280, height: 900 };

async function waitFlutterReady(page) {
  await page.waitForLoadState('networkidle', { timeout: 30000 });
  await page.waitForTimeout(3000);
}

async function snap(page, name) {
  const file = path.join(OUT_DIR, name);
  await page.screenshot({ path: file, fullPage: false });
  console.log(`  captured ${name} (${(fs.statSync(file).size / 1024).toFixed(1)} KB)`);
}

(async () => {
  fs.mkdirSync(OUT_DIR, { recursive: true });
  const browser = await chromium.launch({ headless: true });
  const ctx = await browser.newContext({ viewport: VIEWPORT });
  const page = await ctx.newPage();

  page.on('console', msg => {
    if (msg.type() === 'error') console.log('  [console error]', msg.text());
  });
  page.on('pageerror', err => console.log('  [page error]', err.message));

  console.log('--- Phase 1: Initial Dashboard (TC-02) ---');
  await page.goto(APP_URL, { waitUntil: 'domcontentloaded' });
  await waitFlutterReady(page);
  await page.waitForTimeout(2000);
  await snap(page, 'tc02_auto_connect.png');

  console.log('--- Phase 2: Phase plan panel (TC-17, TC-18) ---');
  await page.mouse.wheel(0, 400);
  await page.waitForTimeout(1000);
  await snap(page, 'tc17_phase_config.png');
  await page.mouse.wheel(0, -400);
  await page.waitForTimeout(500);

  console.log('--- Phase 3: Dashboard overview (TC-14) ---');
  await snap(page, 'tc14_vietnamese_ui.png');

  await browser.close();
  console.log('\nDone. Output in', OUT_DIR);
})();
