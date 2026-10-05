// SPIKE TEST (peak-load test)
//
// Question it answers: what happens when traffic jumps far beyond normal, and
// does the system recover afterwards?
//
// The script body is identical to the load test. Only the load profile and the
// thresholds change - and that is the whole point: a test type is a shape of
// traffic plus the expectations you attach to it, not a different test.
//
// Thresholds here are deliberately looser than in the load test. Degrading
// under a 20x spike is acceptable; falling over and staying down is not.
//
//   make spike
//   make spike K6_FLAGS="-o experimental-prometheus-rw"   # watch it in Grafana

import http from "k6/http";
import { check, sleep } from "k6";
import { Counter, Trend } from "k6/metrics";

import { BASE_URL, headers, parseJSON, restrictions } from "./lib/config.js";
import { SPIKE_STAGES } from "./lib/stages.js";

const pizzasCreated = new Counter("pizzas_created");
const pizzaCalories = new Trend("pizza_calories");

export const options = {
  stages: SPIKE_STAGES,
  thresholds: {
    // We tolerate some failures at the peak, but not a collapse.
    http_req_failed: ["rate<0.05"],
    // 4x the load-test budget: slower is fine, timing out is not.
    http_req_duration: ["p(95)<2000"],
    checks: ["rate>0.95"],
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

  const ok = check(res, {
    "status is 200": (r) => r.status === 200,
    "response has a pizza name": () => !!body?.pizza?.name,
    "no excluded ingredient was used": () =>
      body?.pizza?.ingredients?.every(
        (i) => !restrictions.excludedIngredients.includes(i.name),
      ) === true,
    // Best effort, not guaranteed - see the note in 02-load.js.
    "calories within the requested limit": () =>
      body?.calories <= restrictions.maxCaloriesPerSlice,
  });

  if (ok) {
    pizzasCreated.add(1);
    pizzaCalories.add(body.calories);
  }

  sleep(1);
}
