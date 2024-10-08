import { browser } from 'k6/browser';
import { check } from "k6";

export async function LoadAndCheck(url, headless) {
  let checkData;
  const page = await browser.newPage();
  
  try {
    await page.goto(url)
    checkData = await page.locator("h1").textContent();
    check(page, {
      header: checkData == "Looking to break out of your pizza routine?",
    });
  
    await page.locator('//button[. = "Pizza, Please!"]').click();
    await page.waitForTimeout(500);
    await page.screenshot({ path: `screenshots/${__ITER}.png` });
    checkData = await page.locator("div#recommendations").textContent();
    check(page, {
      recommendation: checkData != "",
    });
  } finally {
    await page.close();
  }
}