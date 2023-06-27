import http from "k6/http";
import { check, sleep } from "k6";
import { ServiceDisruptor } from "k6/x/disruptor";

const BASE_URL = __ENV.BASE_URL || "http://localhost:3333";

const scenarios = {
  disrupt: {
    executor: "shared-iterations",
    iterations: 1,
    exec: "disrupt",
  },
  load: {
    executor: "constant-vus",
    vus: 5,
    duration: "30s",
    startTime: "10s",
  },
};
if (__ENV.DISABLE_DISRUPT) {
  delete scenarios["disrupt"];
}

export const options = {
  scenarios: scenarios,
};

export function disrupt(data) {
  const disruptor = new ServiceDisruptor("pizza-info", "pizza-ns");
  const targets = disruptor.targets();
  if (targets.length == 0) {
    throw new Error("expected list to have one target");
  }

  disruptor.injectHTTPFaults({ averageDelay: "1000ms" }, "40s");
}

export default function () {
  let restrictions = {
    max_calories_pers_slice: 500,
    must_be_vegetarian: false,
    excluded_ingredients: ["pepperoni"],
    excluded_tools: ["knife"],
    max_number_of_toppings: 6,
    min_number_of_toppings: 2,
  };
  let res = http.post(`${BASE_URL}/api/pizza`, JSON.stringify(restrictions), {
    headers: {
      "Content-Type": "application/json",
      "X-User-ID": 23423,
    },
  });
  check(res, { "status is 200": (res) => res.status === 200 });
  console.log(
    `${res.json().pizza.name} (${
      res.json().pizza.ingredients.length
    } ingredients)`
  );
  sleep(1);
}
