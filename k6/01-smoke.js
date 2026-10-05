// SMOKE TEST
//
// Question it answers: does the system work at all under minimal load?
//
// A smoke test is the cheapest test you own. One virtual user, half a minute.
// Run it after every deploy, and always before any heavier test - there is no
// point stressing a system that is already broken.
//
//   make smoke
//
// Thresholds are strict on purpose: at this load *nothing* is allowed to fail.

import http from "k6/http";
import { check, sleep } from "k6";

import { BASE_URL, headers, parseJSON, restrictions } from "./lib/config.js";
import { SMOKE } from "./lib/stages.js";

export const options = {
  ...SMOKE,
  thresholds: {
    // No request may fail.
    http_req_failed: ["rate==0"],
    // Every check must pass.
    checks: ["rate==1"],
    // Generous: we are only proving the thing responds, not measuring it.
    http_req_duration: ["p(95)<1000"],
  },
};

// setup() runs once, before any virtual user starts. Use it to fail fast with a
// clear message instead of drowning in connection errors.
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

  // Parse defensively: a failing server may answer with something that is not
  // JSON at all, and an exception inside a check would abort the iteration.
  const body = parseJSON(res);

  // A check records a pass/fail result. It does NOT stop the test and it does
  // NOT fail the run on its own - the `checks` threshold above is what turns
  // these into a pass/fail gate.
  // Note these are all *hard* invariants - things the server always guarantees.
  // That is what lets us demand a 100% pass rate above. The load test adds a
  // best-effort rule on top, with a threshold that tolerates the odd miss.
  check(res, {
    "status is 200": (r) => r.status === 200,
    "response has a pizza name": () => !!body?.pizza?.name,
    // A business rule, not just a status code: we excluded an ingredient and
    // the recipe must not contain it.
    "no excluded ingredient was used": () =>
      body?.pizza?.ingredients?.every(
        (i) => !restrictions.excludedIngredients.includes(i.name),
      ) === true,
  });

  sleep(1);
}
