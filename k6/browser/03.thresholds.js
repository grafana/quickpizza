import { browser } from "k6/browser";
import { check } from 'https://jslib.k6.io/k6-utils/1.5.0/index.js';

const BASE_URL = __ENV.BASE_URL || "http://localhost:3333";

export const options = {
  scenarios: {
    ui: {
      executor: "shared-iterations",
      options: {
        browser: {
          type: "chromium",
        },
      },
    },
  },
  thresholds: {
    browser_web_vital_fcp: ["p(95) < 1000"],
    browser_web_vital_lcp: ["p(95) < 2000"],
  },
};

export default async function () {
  let checkData;
  const page = await browser.newPage();
  try {
    await page.goto(BASE_URL);
    checkData = await page.locator("h1").textContent();
    check(checkData, {
      header: checkData == "Looking to break out of your pizza routine?",
    });

    await page.getByRole("button", { name: "Pizza, Please!" }).click();
    await page.waitForTimeout(500);
    await page.screenshot({ path: "screenshot.png" });
    checkData = await page.locator("div#recommendations").textContent();
    check(checkData, {
      recommendation: checkData != "",
    });
  } finally {
    await page.close();
  }
}
