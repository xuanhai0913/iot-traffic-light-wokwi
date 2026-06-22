// capture-full.js — chụp 21 screenshot test case
const { chromium } = require('/tmp/node_modules/playwright');
const path = require('path');
const fs = require('fs');

const APP_URL = 'http://localhost:8080';
const OUT_DIR = '/mnt/c/Users/hainx/OneDrive/Tài liệu/iot-traffic-light-wokwi/assets/e2e';
const VIEWPORT = { width: 1280, height: 900 };

// Bottom tab bar coords (1280x900 viewport)
const TABS = {
  Dashboard: { x: 130, y: 856 },
  Control:   { x: 380, y: 856 },
  Manage:    { x: 640, y: 856 },
  History:   { x: 890, y: 856 },
  Settings:  { x: 1150, y: 856 },
};

async function snap(page, name) {
  const file = path.join(OUT_DIR, name);
  await page.screenshot({ path: file, fullPage: false });
  console.log(`  ✓ ${name}  (${(fs.statSync(file).size / 1024).toFixed(1)} KB)`);
}

async function waitFlutter(page, ms = 3000) {
  await page.waitForLoadState('networkidle', { timeout: 30000 });
  await page.waitForTimeout(ms);
}

async function clickTab(page, name) {
  const c = TABS[name];
  await page.mouse.click(c.x, c.y);
  await page.waitForTimeout(1500);
}

(async () => {
  fs.mkdirSync(OUT_DIR, { recursive: true });
  const browser = await chromium.launch({ headless: true });
  const ctx = await browser.newContext({ viewport: VIEWPORT });
  const page = await ctx.newPage();

  page.on('pageerror', err => console.log('  [page error]', err.message));
  page.on('response', r => {
    if (r.url().includes('/api/') && r.status() >= 400) {
      console.log('  [api 4xx/5xx]', r.status(), r.url().replace('http://localhost:8080', ''));
    }
  });

  console.log('=== Phase 1: Dashboard (TC-02, TC-03, TC-14) ===');
  await page.goto(APP_URL, { waitUntil: 'domcontentloaded' });
  await waitFlutter(page, 4000);
  await snap(page, 'tc02_auto_connect.png');
  await snap(page, 'tc14_vietnamese_ui.png');
  await page.waitForTimeout(2000);
  await snap(page, 'tc03_polling.png');

  console.log('=== Phase 2: Control tab (TC-04, TC-05, TC-06, TC-08, TC-09) ===');
  await clickTab(page, 'Control');
  await page.waitForTimeout(2000);
  await snap(page, 'tc_control_view.png');

  // Click AUTO button — center of button at y=197
  console.log('  → click AUTO');
  await page.mouse.click(640, 197);
  await page.waitForTimeout(1500);
  await snap(page, 'tc04_auto_result.png');
  // Click "Close" on result dialog (center-bottom of dialog)
  await page.mouse.click(770, 550);
  await page.waitForTimeout(1500);

  // Click NIGHT — y=268
  console.log('  → click NIGHT');
  await page.mouse.click(640, 268);
  await page.waitForTimeout(1500);
  await snap(page, 'tc05_night_result.png');
  await page.mouse.click(770, 550);
  await page.waitForTimeout(1500);

  // Click PRIORITY NS — y=339 (3rd button)
  console.log('  → click PRIORITY NS (expect confirm dialog)');
  await page.mouse.click(640, 339);
  await page.waitForTimeout(2000);
  await snap(page, 'tc06_priority_ns_confirm.png');

  // Click "Send anyway" — bottom-right of dialog (orange FilledButton)
  // Dialog center is around x=640, send button at x=750, y=540
  await page.mouse.click(750, 540);
  await page.waitForTimeout(1500);
  await snap(page, 'tc07_priority_ns_result.png');
  await page.mouse.click(770, 550);
  await page.waitForTimeout(1500);

  // Click PRIORITY EW — y=410 (4th button)
  console.log('  → click PRIORITY EW');
  await page.mouse.click(640, 410);
  await page.waitForTimeout(2000);
  await snap(page, 'tc08_priority_ew_confirm.png');
  await page.mouse.click(750, 540);
  await page.waitForTimeout(1500);
  await snap(page, 'tc08_priority_ew_result.png');
  await page.mouse.click(770, 550);
  await page.waitForTimeout(1500);

  // Click EMERGENCY — y=481 (5th button, red)
  console.log('  → click EMERGENCY');
  await page.mouse.click(640, 481);
  await page.waitForTimeout(2000);
  await snap(page, 'tc09_emergency_confirm.png');
  await page.mouse.click(750, 540);
  await page.waitForTimeout(1500);
  await snap(page, 'tc09_emergency_result.png');
  await page.mouse.click(770, 550);
  await page.waitForTimeout(1500);

  console.log('=== Phase 3: Manage tab (TC-17, TC-18, TC-19) ===');
  await clickTab(page, 'Manage');
  await page.waitForTimeout(2000);
  await snap(page, 'tc17_phase_config.png');
  await page.mouse.wheel(0, 400);
  await page.waitForTimeout(1000);
  await snap(page, 'tc19_approach_toggle.png');

  console.log('=== Phase 4: History tab (TC-20) ===');
  await clickTab(page, 'History');
  await page.waitForTimeout(2000);
  await snap(page, 'tc20_history_tab.png');

  console.log('=== Phase 5: Settings tab (TC-15, TC-16) ===');
  await clickTab(page, 'Settings');
  await page.waitForTimeout(2000);
  await snap(page, 'tc15_api_base_settings.png');
  await page.mouse.wheel(0, 300);
  await page.waitForTimeout(1000);
  await snap(page, 'tc16_skip_confirm.png');

  console.log('=== Phase 6: Connection state (TC-10, TC-11) ===');
  // TC-10: success snackbar appears after any command
  // Re-do an AUTO command and capture the snackbar
  await clickTab(page, 'Control');
  await page.waitForTimeout(1500);
  await page.mouse.click(640, 197);
  await page.waitForTimeout(400);
  await snap(page, 'tc10_success_snackbar.png');

  // TC-11: error snackbar — kill backend, then click
  // (Will be done in a separate run)

  await browser.close();
  console.log('\n✓ Done. Output in', OUT_DIR);
})();
