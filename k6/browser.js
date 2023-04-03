import { chromium } from 'k6/experimental/browser';
import { check } from 'k6';

const BASE_URL = __ENV.BASE_URL || 'http://localhost:3333';

export default async function () {
  const browser = chromium.launch({ headless: false });
  const page = browser.newPage();

  try {
    await page.goto(BASE_URL, { waitUntil: 'networkidle' })
    page.screenshot({ path: 'screenshot.png' });
    check(page, {
      'header': page.locator('h1').textContent() == 'Looking to break out of your pizza routine?',
    });
  } finally {
    page.close();
    browser.close();
  }
}