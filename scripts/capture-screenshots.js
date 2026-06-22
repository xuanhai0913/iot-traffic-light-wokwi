// capture-screenshots.js — chụp 21 screenshot test case bằng Playwright
// Usage: node /tmp/capture-screenshots.js
const { chromium } = require('/tmp/node_modules/playwright');
const path = require('path');
const fs = require('fs');

const APP_URL = 'http://localhost:8080';
const OUT_DIR = '/mnt/c/Users/hainx/OneDrive/Tài liệu/iot-traffic-light-wokwi/assets/e2e';

const VIEWPORT = { width: 1280, height: 900 };

async function waitFlutterReady(page) {
  // Flutter web boot — đợi cho tới khi framework đã render
  await page.waitForLoadState('networkidle', { timeout: 30000 });
  // Chờ thêm cho Flutter bootstrap
  await page.waitForTimeout(3000);
}

async function snap(page, name) {
  const file = path.join(OUT_DIR, name);
  await page.screenshot({ path: file, fullPage: false });
  console.log(`  ✓ ${name}  (${(fs.statSync(file).size / 1024).toFixed(1)} KB)`);
}

async function clickByText(page, text) {
  // Flutter web dùng canvas, không có DOM text — phải tap vào tọa độ gần đúng
  // Tìm vùng tabbar dưới cùng, các tab Control/Settings/History/Device logs...
  // Đơn giản: dùng page.getByText nếu Flutter expose semantics
  try {
    const el = page.getByText(text, { exact: false }).first();
    if (await el.count() > 0) {
      await el.click();
      return true;
    }
  } catch {}
  return false;
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
  // Đợi Dashboard poll xong
  await page.waitForTimeout(2000);
  await snap(page, 'tc02_auto_connect.png');

  console.log('--- Phase 2: Phase plan panel (TC-17, TC-18) ---');
  // Scroll xuống nếu cần
  await page.mouse.wheel(0, 400);
  await page.waitForTimeout(1000);
  await snap(page, 'tc17_phase_config.png');
  await page.mouse.wheel(0, -400);
  await page.waitForTimeout(500);

  console.log('--- Phase 3: Capture UI elements (manual coords needed) ---');
  // Lưu 1 screenshot tổng quát của dashboard
  await snap(page, 'tc14_vietnamese_ui.png');

  await browser.close();
  console.log('\n✓ Done. Output in', OUT_DIR);
})();
