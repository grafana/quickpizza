import { browser } from 'k6/experimental/browser';
import { check } from "k6";

export async function LoadAndCheck(url, headless) {
  const page = browser.newPage();
  
  try {
    await page.goto(url)
    check(page, {
      'header': page.locator('h1').textContent() == 'Looking to break out of your pizza routine?',
    });
  
    await page.locator('//button[. = "Pizza, Please!"]').click();
    page.waitForTimeout(500);
    page.screenshot({ path: `screenshots/${__ITER}.png` });
    check(page, {
      'recommendation': page.locator('div#recommendations').textContent() != '',
    });
  } finally {
    page.close();
  }
}