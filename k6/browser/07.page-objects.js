import { browser } from "k6/experimental/browser";
import { describe, expect } from 'https://jslib.k6.io/k6chaijs/4.3.4.3/index.js';

import { LoginPage } from "./pages/login-page.js";
import { RecommendationsPage } from "./pages/recommendations-page.js";

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

export async function admin() {
  describe("Login as admin", async () => {
    const page = browser.newPage();

    try {
      const loginPage = new LoginPage(page);
      await loginPage.goto(BASE_URL);
      await loginPage.login();
      expect(loginPage.getLogoutButtonText(), "logout button text").to.be.equal("Logout");
    } finally {
      page.close();
    }
  })
}

export function pizzaRecommendations() {
  describe("Get pizza recommendations", async () => {
    const page = browser.newPage();

    try {
      const recommendationsPage = new RecommendationsPage(page);
      await recommendationsPage.goto(BASE_URL);
      expect(recommendationsPage.getHeadingTextContent(), "text content").to.equal("Looking to break out of your pizza routine?");
      await recommendationsPage.getPizzaRecommendation();
      expect(recommendationsPage.getPizzaRecommendationsContent(), "pizza recommendations").to.not.be.empty;
    } finally {
      page.close();
    }
  })
}
