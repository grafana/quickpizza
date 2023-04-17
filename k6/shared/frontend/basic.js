import { chromium } from 'k6/experimental/browser';
import { check, sleep } from "k6";

export async function LoadAndCheck(url, headless) {
  const browser = chromium.launch({ headless: headless });
  const context = browser.newContext(
    { viewport: { width: 1920, height: 1080 } },
  );
  const page = context.newPage();
  
  try {
    await page.goto(url, { waitUntil: 'networkidle' })
    check(page, {
      'header': page.locator('h1').textContent() == 'Looking to break out of your pizza routine?',
    });
  
    await page.click('button', { text: 'Pizza, Please!' });
    await page.waitForTimeout(500);
    page.screenshot({ path: `screenshots/${__ITER}.png` });
    check(page, {
      'recommendation': page.locator('div#recommendations').textContent() != '',
    });
  } finally {
    page.close();
    browser.close();
  }
}