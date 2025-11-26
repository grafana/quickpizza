import http from "k6/http";
import { check, sleep } from "k6";
import tracing from "https://jslib.k6.io/http-instrumentation-tempo/1.0.0/index.js";

const BASE_URL = __ENV.BASE_URL || "http://localhost:3333";

export const options = {
  vus: 15,
  duration: "10s",
};

tracing.instrumentHTTP({
  propagator: "w3c",
});

export default function () {
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
      Authorization: "token abcdef0123456789",
      // QuickPizza converts baggage into span attributes
      baggage: "k6_request=true, user_id=12345",
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
