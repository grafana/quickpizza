import { chromium } from 'k6/experimental/browser';
import { check } from 'k6';

const BASE_URL = __ENV.BASE_URL || 'http://localhost:3333';

export default async function () {
  const browser = chromium.launch({ headless: true });
  const context = browser.newContext(
    { viewport: { width: 1920, height: 1080 } },
  );
  const page = context.newPage();

  try {
    await page.goto(BASE_URL, { waitUntil: 'networkidle' })
    check(page, {
      'header': page.locator('h1').textContent() == 'Looking to break out of your pizza routine?',
    });

    await page.click('button', { text: 'Pizza, Please!' });
    await page.waitForTimeout(500);
    page.screenshot({ path: 'screenshot.png' });
    check(page, {
      'recommendation': page.locator('div#recommendations').textContent() != '',
    });
  } finally {
    page.close();
    browser.close();
  }
}