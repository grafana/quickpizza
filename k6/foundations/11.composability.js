import http from "k6/http";
import { check, sleep } from "k6";
import { Trend, Counter } from "k6/metrics";
import { textSummary } from "https://jslib.k6.io/k6-summary/0.0.2/index.js";
import { SharedArray } from "k6/data";
import { browser } from "k6/browser";

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
        { duration: "5s", target: 5 },
        { duration: "10s", target: 5 },
        { duration: "5s", target: 0 },
      ],
      startTime: "10s",
    },
    browser: {
      exec: "checkFrontend",
      executor: "constant-vus",
      vus: 1,
      duration: "15s",
      options: {
        browser: {
          type: "chromium",
        },
      },
    },
  },
  thresholds: {
    http_req_failed: ["rate<0.01"],
    http_req_duration: ["p(95)<500", "p(99)<1000"],
    quickpizza_ingredients: [{ threshold: "avg<8", abortOnFail: false }],
    checks: ["rate > 0.95"],
  },
};

const pizzas = new Counter("quickpizza_number_of_pizzas");
const ingredients = new Trend("quickpizza_ingredients");

const tokens = new SharedArray("all tokens", function () {
  return JSON.parse(open("./data/tokens.json")).tokens;
});

export function setup() {
  let res = http.get(BASE_URL);
  if (res.status !== 200) {
    throw new Error(
      `Got unexpected status code ${res.status} when trying to setup. Exiting.`
    );
  }
}

export function getPizza() {
  let restrictions = {
    maxCaloriesPerSlice: 500,
    mustBeVegetarian: false,
    excludedIngredients: ["pepperoni"],
    excludedTools: ["knife"],
    maxNumberOfToppings: 6,
    minNumberOfToppings: 2,
  };
  let res = http.post(`${BASE_URL}/api/pizza`, JSON.stringify(restrictions), {
    headers: {
      "Content-Type": "application/json",
      "Authorization": "Token " + tokens[Math.floor(Math.random() * tokens.length)],
    },
  });
  check(res, { "status is 200": (res) => res.status === 200 });
  console.log(
    `${res.json().pizza.name} (${
      res.json().pizza.ingredients.length
    } ingredients)`
  );
  pizzas.add(1);
  ingredients.add(res.json().pizza.ingredients.length);
  sleep(1);
}

export async function checkFrontend() {
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

export function teardown() {
  // TODO: Send notification to Slack
  console.log("That's all folks!");
}

export function handleSummary(data) {
  return {
    "summary.json": JSON.stringify(data, null, 2),
    stdout: textSummary(data, { indent: " ", enableColors: true }),
  };
}
