import { chromium } from 'k6/experimental/browser';
import { check, sleep } from "k6";

export async function LoadAndCheck(url, headless) {
  const browser = chromium.launch({ headless: headless });
  const page = browser.newPage();

  try {
    await page.goto(url, { waitUntil: 'networkidle' })
    page.screenshot({ path: `screenshots/${__ITER}.png` });
    check(page, {
      'header': page.locator('h1').textContent() == 'Looking to break out of your pizza routine?',
    });
  } finally {
    page.close();
    browser.close();
  }
}