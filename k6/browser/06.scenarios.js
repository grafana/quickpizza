import { browser } from "k6/experimental/browser";
import { describe, expect } from 'https://jslib.k6.io/k6chaijs/4.3.4.3/index.js';

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
      exec: 'pizzaRecommendations'
    },
    admin: {
      executor: "shared-iterations",
      options: {
        browser: {
          type: "chromium",
        },
      },
      exec: 'admin'
    },
  },
  thresholds: {
    browser_web_vital_fcp: ["p(95) < 1000"],
    browser_web_vital_lcp: ["p(95) < 2000"],
    checks: ["rate > 0.9"]
  }
};

export function admin() {
  describe("Login as admin", async () => {
    const page = browser.newPage();

    try {
      await page.goto(`${BASE_URL}/admin`);
      await page.locator('button[type="submit"]').click();
      expect(page.locator('//*[text()="Logout"]').textContent(), "logout button text").to.be.equal("Logout");
    } finally {
      page.close();
    }
  })
}

export function pizzaRecommendations() {
  describe("Get pizza recommendations", async () => {
    const page = browser.newPage();

    try {
      await page.goto(BASE_URL);

      expect(page.locator("h1").textContent(), "text content").to.equal("Looking to break out of your pizza routine?");

      await page.locator('//button[. = "Pizza, Please!"]').click();
      page.waitForTimeout(500);
      page.screenshot({ path: "screenshot.png" });

      expect(page.locator("div#recommendations").textContent(), "pizza recommendations").to.not.be.empty;
    } finally {
      page.close();
    }
  })
}
