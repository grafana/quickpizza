import { browser } from "k6/experimental/browser";
import { check, sleep } from "k6";
import http from "k6/http";
import { Trend } from "k6/metrics";

import { LoginPage } from "./pages/login-page.js";
import { RecommendationsPage } from "./pages/recommendations-page.js";
import { PageUtils } from "./pages/page-utils.js";

const BASE_URL = __ENV.BASE_URL || "http://localhost:3333";

export const options = {
  scenarios: {
    smoke: {
      exec: "getPizza",
      executor: "constant-vus",
      vus: 1,
      duration: "10s",
    },
    stress: {
      exec: "getPizza",
      executor: "ramping-vus",
      stages: [
        { duration: '5s', target: 5 },
        { duration: '10s', target: 5 },
        { duration: '5s', target: 0 },
      ],
      startTime: "10s",
    },
    pizzaRecommendations: {
      executor: "constant-vus",
      vus: 1,
      duration: "30s",
      options: {
        browser: {
          type: "chromium",
        },
      },
      exec: 'pizzaRecommendations'
    },
    admin: {
      executor: "constant-vus",
      vus: 1,
      duration: "30s",
      options: {
        browser: {
          type: "chromium",
        },
      },
      exec: 'admin'
    },
  },
  thresholds: {
    http_req_failed: ['rate<0.01'],
    http_req_duration: ['p(95)<500', 'p(99)<1000'],
    browser_web_vital_fcp: ["p(95) < 1000"],
    browser_web_vital_lcp: ["p(95) < 2000"],
  }
};

const myTrend = new Trend('totalActionTime');

export function getPizza() {
  let restrictions = {
    maxCaloriesPerSlice: 500,
    mustBeVegetarian: false,
    excludedIngredients: ["pepperoni"],
    excludedTools: ["knife"],
    maxNumberOfToppings: 6,
    minNumberOfToppings: 2
  }
  let res = http.post(`${BASE_URL}/api/pizza`, JSON.stringify(restrictions), {
    headers: {
      'Content-Type': 'application/json',
      'X-User-ID': 123456,
    },
  });
  check(res, { "status is 200": (res) => res.status === 200 });
  sleep(1);
}

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