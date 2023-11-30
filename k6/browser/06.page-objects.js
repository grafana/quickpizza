import { browser } from "k6/experimental/browser";
import { check } from "k6";
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
    browser_web_vital_fcp: ["p(95) < 1000"],
    browser_web_vital_lcp: ["p(95) < 2000"],
  }
};

const myTrend = new Trend('totalActionTime');

export async function admin() {
  const page = browser.newPage();

  try {
    const loginPage = new LoginPage(page);
    await loginPage.goto(BASE_URL);
    await loginPage.login();

    check(loginPage, {
      "logout button text": loginPage.getLogoutButtonText() == "Logout",
    });
  } finally {
    page.close();
  }
}

export async function pizzaRecommendations() {
  const page = browser.newPage();
  const recommendationsPage = new RecommendationsPage(page);
  const pageUtils = new PageUtils(page);

  try {
    await recommendationsPage.goto(BASE_URL);
    pageUtils.addPerformanceMark('page-visit');

    check(recommendationsPage, {
      header: recommendationsPage.getHeadingTextContent() == "Looking to break out of your pizza routine?",
    });

    await recommendationsPage.getPizzaRecommendation();
    pageUtils.addPerformanceMark('recommendations-returned');

    check(recommendationsPage, {
      recommendation: recommendationsPage.getPizzaRecommendationsContent() != "",
    });

    //Get time difference between visiting the page and pizza recommendations returned
    pageUtils.measurePerformance('total-action-time', 'page-visit', 'recommendations-returned')

    const totalActionTime = pageUtils.getPerformanceDuration('total-action-time');
    myTrend.add(totalActionTime);
  } finally {
    page.close();
  }
}