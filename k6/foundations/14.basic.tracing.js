import http from "k6/http";
import { check, sleep } from "k6";
import tracing from 'k6/experimental/tracing';

const BASE_URL = __ENV.BASE_URL || 'http://localhost:3333';

export const options = {
  vus: 15,
  duration: '1m',
};

tracing.instrumentHTTP({
  propagator: 'w3c',
});

export default function () {
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
  sleep(1);
}