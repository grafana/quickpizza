import { browser } from "k6/browser";
import { check } from "k6";

const BASE_URL = __ENV.BASE_URL || "http://localhost:3333";

export const options = {
  scenarios: {
    pizzaRecommendations: {
      executor: "shared-iterations",
      options: {
        browser: {
          type: "chromium",
        },
      },
      exec: "pizzaRecommendations",
    },
    admin: {
      executor: "shared-iterations",
      options: {
        browser: {
          type: "chromium",
        },
      },
      exec: "admin",
    },
  },
  thresholds: {
    browser_web_vital_fcp: ["p(95) < 1000"],
    browser_web_vital_lcp: ["p(95) < 2000"],
  },
};

export async function admin() {
  let checkData;
  const page = await browser.newPage();

  try {
    await page.goto(`${BASE_URL}/admin`);
    await page.locator('button[type="submit"]').click();
    checkData = await page.locator('//*[text()="Logout"]').textContent();
    check(page, {
      "logout button text": checkData == "Logout",
    });
  } finally {
    await page.close();
  }
}

export async function pizzaRecommendations() {
  let checkData;
  const page = await browser.newPage();
  try {
    await page.goto(BASE_URL);
    checkData = await page.locator("h1").textContent();
    check(page, {
      header: checkData == "Looking to break out of your pizza routine?",
    });

    await page.locator('//button[. = "Pizza, Please!"]').click();
    await page.waitForTimeout(500);
    await page.screenshot({ path: "screenshot.png" });
    checkData = await page.locator("div#recommendations").textContent();
    check(page, {
      recommendation: checkData != "",
    });
  } finally {
    await page.close();
  }
}
