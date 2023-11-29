import http from "k6/http";
import { check, sleep } from "k6";
import { Trend, Counter } from "k6/metrics";
import { textSummary } from "https://jslib.k6.io/k6-summary/0.0.2/index.js";

const BASE_URL = __ENV.BASE_URL || 'http://localhost:3333';

export const options = {
  scenarios: {
    constant_request_rate: {
      exec: "getPizza",
      executor: 'constant-arrival-rate',
      duration: '30s',

      // Given `rate` and `timeUnit`, this test runs 20 iterations/s.
      rate: 20, // Iterations rate.
      timeUnit: '1s', // `timeUnit` rate. Default is 1s.

      // Required. k6 warns during execution 
      // if more VUs are needed to reach the desired iteration rate.
      preAllocatedVUs: 60,
    },
  },
  thresholds: {
    http_req_failed: ['rate<0.01'],
    http_req_duration: ['p(95)<500', 'p(99)<1000'],
    quickpizza_ingredients: [{ threshold: 'avg<8', abortOnFail: false }],
    checks: ["rate > 0.95"]
  },
};

const pizzas = new Counter('quickpizza_number_of_pizzas');
const ingredients = new Trend('quickpizza_ingredients');

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
      'X-User-ID': 23423,
    },
  });
  check(res, { "status is 200": (res) => res.status === 200 });
  console.log(`${res.json().pizza.name} (${res.json().pizza.ingredients.length} ingredients)`);
  pizzas.add(1);
  ingredients.add(res.json().pizza.ingredients.length);

  // sleep(1); 
  /*
  This test aims to achieve a constant request rate of 20 requests per second.

  Pausing (sleep) is undesirable for maintaining a constant request rate.

  If the iteration primarily involves performing requests, then 
  the iteration rate is almost equivalent to the request rate.

  20 iterations per second x 1 request per iteration = 20 requests per second

  output: iterations.....................: 600     19.963596/s
  */
}

export function teardown() {
  // TODO: Send notification to Slack
  console.log("That's all folks!")
}

export function handleSummary(data) {
  return {
    'summary.json': JSON.stringify(data, null, 2),
    stdout: textSummary(data, { indent: " ", enableColors: true }),
  }
}