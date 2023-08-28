import http from "k6/http";
import { check, sleep } from "k6";
import { Trend, Counter } from "k6/metrics";
import { textSummary } from "https://jslib.k6.io/k6-summary/0.0.2/index.js";
import { SharedArray } from 'k6/data';
import { LoadAndCheck } from "./lib/frontend/basic.js";
import internal from 'k6/x/internal';

const BASE_URL = __ENV.BASE_URL || 'http://localhost:3333';

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
      gracefulRampDown: "5s",
      startTime: "10s",
    },
    browser: {
      exec: "checkFrontend",
      executor: "constant-vus",
      vus: 1,
      duration: "30s"
    }
  },
  thresholds: {
    http_req_failed: ['rate<0.01'],
    http_req_duration: ['p(95)<500', 'p(99)<1000'],
    quickpizza_ingredients: [{ threshold: 'avg<8', abortOnFail: false }],
  },
};

const pizzas = new Counter('quickpizza_number_of_pizzas');
const ingredients = new Trend('quickpizza_ingredients');

const customers = new SharedArray('all my customers', function () {
  return JSON.parse(open('./data/customers.json')).customers;
});

export function setup() {
  let res = http.get(BASE_URL)
  if (res.status !== 200) {
    throw new Error(`Got unexpected status code ${res.status} when trying to setup. Exiting.`)
  }
}

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
      'X-User-ID': customers[Math.floor(Math.random() * customers.length)],
    },
  });
  check(res, { "status is 200": (res) => res.status === 200 });
  check (res, { "pizza follows restrictions": (res) => { 
    if (internal.checkRestrictions(res.json().pizza, restrictions) === false) {
      console.log(`${res.json().pizza.name} does not follow restrictions: ${internal.getCheckResult()}`);
      return false;
    } else {
      return true;
    }
  }});
  console.log(`${res.json().pizza.name} (${res.json().pizza.ingredients.length} ingredients)`);
  pizzas.add(1);
  ingredients.add(res.json().pizza.ingredients.length);
  sleep(1);
}

export async function checkFrontend() {
  await LoadAndCheck(BASE_URL, true);
}

export function teardown(){
  // TODO: Send notification to Slack
  console.log("That's all folks!")
}

export function handleSummary(data) {
  return {
    'summary.json': JSON.stringify(data, null, 2),
    stdout: textSummary(data, { indent: " ", enableColors: true }),
  }
}