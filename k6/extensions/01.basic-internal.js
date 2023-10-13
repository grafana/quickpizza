import http from "k6/http";
import { check, sleep } from "k6";
import internal from 'k6/x/internal';

const BASE_URL = __ENV.BASE_URL || 'http://localhost:3333';

export const options = {
  vus: 5,
  duration: '5s',
};

export default function() {
  let restrictions = {
    maxCaloriesPerSlice: 500,
    mustBeVegetarian: false,
    excludedIngredients: ["pepperoni"],
    excludedTools: ["knife"],
    maxNumberOfToppings: 4,
    minNumberOfToppings: 1
  }
  let res = http.post(`${BASE_URL}/api/pizza`, JSON.stringify(restrictions), {
    headers: {
      'Content-Type': 'application/json',
      'X-User-ID': 23423,
    },
  });
  check(res, { "status is 200": (res) => res.status === 200 });

  console.log(`${res.json().pizza.name} (${res.json().pizza.ingredients.length} ingredients)`);
  check (res, { "pizza follows restrictions": (res) => { 
    const followRestrictions = internal.checkRestrictions(res.json().pizza, restrictions);
    if (!followRestrictions) {
      console.log(`${res.json().pizza.name} does not follow restrictions: ${internal.getCheckResult()}`);
    }
    return followRestrictions;
  }});
  sleep(1);
}