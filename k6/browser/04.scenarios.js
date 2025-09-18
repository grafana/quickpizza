import { browser } from "k6/browser";
import { check } from 'https://jslib.k6.io/k6-utils/1.5.0/index.js';

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
    browser_web_vital_fcp: ["p(95) < 3000"],
    browser_web_vital_lcp: ["p(95) < 4000"],
  },
};

export async function admin() {
  let checkData;
  const page = await browser.newPage();

  try {
    await page.goto(`${BASE_URL}/admin`, { waitUntil: "networkidle" });
    await page.getByRole("button", { name: "Sign in" }).click();
    checkData = await page.getByRole("button", { name: "Logout" }).textContent();
    check(checkData, {
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
