import { browser } from "k6/experimental/browser";
import { describe, expect } from 'https://jslib.k6.io/k6chaijs/4.3.4.3/index.js';

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
};

export default async function () {
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
