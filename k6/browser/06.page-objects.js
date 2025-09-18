import { browser } from "k6/browser";
import { check } from 'https://jslib.k6.io/k6-utils/1.5.0/index.js';
import { Trend } from "k6/metrics";

import { LoginPage } from "./pages/login-page.js";
import { RecommendationsPage } from "./pages/recommendations-page.js";
import { PageUtils } from "./pages/page-utils.js";

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
    browser_web_vital_fcp: ["p(95) < 3000"],
    browser_web_vital_lcp: ["p(95) < 4000"],
  }
};

const myTrend = new Trend('totalActionTime');

export async function admin() {
  const page = await browser.newPage();

  try {
    const loginPage = new LoginPage(page);
    await loginPage.goto(BASE_URL);
    await loginPage.login();

    check(loginPage, {
      "logout button text": await loginPage.getLogoutButtonText() == "Logout",
    });
  } finally {
    await page.close();
  }
}

export async function pizzaRecommendations() {
  const page = await browser.newPage();
  const recommendationsPage = new RecommendationsPage(page);
  const pageUtils = new PageUtils(page);

  try {
    await recommendationsPage.goto(BASE_URL);
    await pageUtils.addPerformanceMark('page-visit');

    check(recommendationsPage, {
      header: await recommendationsPage.getHeadingTextContent() == "Looking to break out of your pizza routine?",
    });

    await recommendationsPage.getPizzaRecommendation();
    await pageUtils.addPerformanceMark('recommendations-returned');

    check(recommendationsPage, {
      recommendation: await recommendationsPage.getPizzaRecommendationsContent() != "",
    });

    //Get time difference between visiting the page and pizza recommendations returned
    await pageUtils.measurePerformance('total-action-time', 'page-visit', 'recommendations-returned')

    const totalActionTime = await pageUtils.getPerformanceDuration('total-action-time');
    myTrend.add(totalActionTime);
  } finally {
    await page.close();
  }
}
