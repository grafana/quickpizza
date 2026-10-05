// LOAD TEST (performance test)
//
// Question it answers: does the system meet its performance targets under the
// traffic we actually expect?
//
// Same user journey as the smoke test, but now we ramp up to a realistic load,
// hold it steady, and judge the steady state against SLOs expressed as
// thresholds. This is also where custom metrics start to earn their keep:
// response time tells you the system is fast, but not that it is *correct*.
//
//   make load
//   make load K6_FLAGS="-o experimental-prometheus-rw"   # watch it in Grafana

import http from "k6/http";
import { check, sleep } from "k6";
import { Counter, Trend } from "k6/metrics";

import { BASE_URL, headers, parseJSON, restrictions } from "./lib/config.js";
import { LOAD_STAGES } from "./lib/stages.js";

// Custom metrics. k6 gives you timing and error rate for free; anything about
// your domain you have to measure yourself.
//
//   Counter - a number that only goes up (how many pizzas did we create?)
//   Trend   - a distribution, so you get avg/min/max/percentiles for free
const pizzasCreated = new Counter("pizzas_created");
const pizzaCalories = new Trend("pizza_calories");

export const options = {
  stages: LOAD_STAGES,
  thresholds: {
    // Availability: fewer than 1% of requests may fail.
    http_req_failed: ["rate<0.01"],
    // Latency, as percentiles. Never set an SLO on the average - it hides the
    // slow tail, which is exactly what users complain about.
    http_req_duration: ["p(95)<500", "p(99)<1000"],
    // Correctness: over 99% of our assertions must hold.
    checks: ["rate>0.99"],
    // A threshold on a custom metric - an SLO on our own domain, not on HTTP.
    pizza_calories: ["max<=500"],
  },
};

export function setup() {
  const res = http.get(`${BASE_URL}/ready`);
  if (res.status !== 200) {
    throw new Error(
      `QuickPizza is not ready at ${BASE_URL} (got ${res.status}). Run "make up" first.`,
    );
  }
}

export default function () {
  const res = http.post(`${BASE_URL}/api/pizza`, JSON.stringify(restrictions), {
    headers,
  });

  const body = parseJSON(res);

  // Under load a service can stay fast while quietly returning wrong answers.
  // Checking only the status code would never catch that, so we also assert the
  // business rules we asked the API to honour.
  const ok = check(res, {
    "status is 200": (r) => r.status === 200,
    "response has a pizza name": () => !!body?.pizza?.name,
    "no excluded ingredient was used": () =>
      body?.pizza?.ingredients?.every(
        (i) => !restrictions.excludedIngredients.includes(i.name),
      ) === true,
    // Best-effort rather than guaranteed: QuickPizza retries recipe generation
    // at most 10 times and then returns whatever it has, so this one misses
    // roughly 0.4% of the time even on a perfectly healthy system. Hence
    // `checks: rate>0.99` rather than `rate==1` - a threshold is a budget.
    "calories within the requested limit": () =>
      body?.calories <= restrictions.maxCaloriesPerSlice,
  });

  // Only record domain metrics for responses we actually got a pizza from,
  // otherwise error responses would skew the distribution.
  if (ok) {
    pizzasCreated.add(1);
    pizzaCalories.add(body.calories);
  }

  sleep(1);
}
