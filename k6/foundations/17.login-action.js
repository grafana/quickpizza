import http from "k6/http";
import { check, sleep } from "k6";
import { SharedArray } from "k6/data";
import exec from "k6/execution";

const BASE_URL = __ENV.BASE_URL || "http://localhost:3333";

export const options = {
  vus: 50,
  duration: "5s",
  thresholds: {
    http_req_failed: ["rate==0"],
  },
};

const users = new SharedArray("all users", function () {
  return JSON.parse(open("./data/users.json")).users;
});

export default function () {
  // Each VU logs in as a different user, like real, distinct users would,
  // instead of every VU hammering the login endpoint as the same "default" account.
  const user = users[(exec.vu.idInTest - 1) % users.length];

  let res;
  res = http.post(`${BASE_URL}/api/csrf-token`, null, {
    headers: {
      "Content-Type": "application/json",
    },
  });
  check(res, { "csrf-token status is 200": (res) => res.status === 200 });

  const loginData = {
    username: user.username,
    password: user.password,
    csrf: res.cookies.csrf_token[0].value,
  };
  res = http.post(
    `${BASE_URL}/api/users/token/login`,
    JSON.stringify(loginData),
    {
      headers: {
        "Content-Type": "application/json",
      },
    }
  );
  check(res, { "login status is 200": (res) => res.status === 200 });
  sleep(0.5);

  let token = res.json().token;
  let pizzaData = {
    maxCaloriesPerSlice: 500,
    mustBeVegetarian: false,
    excludedIngredients: ["pepperoni"],
    excludedTools: ["knife"],
    maxNumberOfToppings: 6,
    minNumberOfToppings: 2,
  };
  res = http.post(`${BASE_URL}/api/pizza`, JSON.stringify(pizzaData), {
    headers: {
      "Content-Type": "application/json",
      Authorization: `token ${token}`,
    },
  });
  check(res, { "pizza status is 200": (res) => res.status === 200 });

  let ratingsData = {
    pizza_id: res.json().pizza.id,
    stars: 5, // Love it!
  };
  res = http.post(`${BASE_URL}/api/ratings`, JSON.stringify(ratingsData), {
    headers: {
      "Content-Type": "application/json",
      Authorization: `token ${token}`,
    },
  });
  check(res, { "ratings status is 201": (res) => res.status === 201 });
  sleep(0.5);
}
