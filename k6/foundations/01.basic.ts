import http from 'k6/http';
import { check, sleep } from 'k6';

const BASE_URL: string = __ENV.BASE_URL || 'http://localhost:3333';

export const options = {
  vus: 5,
  duration: '5s',
};

interface Restrictions {
  maxCaloriesPerSlice: number;
  mustBeVegetarian: boolean;
  excludedIngredients: string[];
  excludedTools: string[];
  maxNumberOfToppings: number;
  minNumberOfToppings: number;
}

export default function (): void {
  const restrictions: Restrictions = {
    maxCaloriesPerSlice: 500,
    mustBeVegetarian: false,
    excludedIngredients: ["pepperoni"],
    excludedTools: ["knife"],
    maxNumberOfToppings: 6,
    minNumberOfToppings: 2,
  };

  const res = http.post(`${BASE_URL}/api/pizza`, JSON.stringify(restrictions), {
    headers: {
      'Content-Type': 'application/json',
      'Authorization': 'token abcdef0123456789',
    },
  });

  check(res, { "status is 200": (res) => res.status === 200 });

  const responseBody = res.json() as { pizza: { name: string; ingredients: string[] } };
  console.log(`${responseBody.pizza.name} (${responseBody.pizza.ingredients.length} ingredients)`);
  sleep(1);
}
