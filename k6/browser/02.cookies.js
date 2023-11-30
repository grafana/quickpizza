import { browser } from "k6/experimental/browser";
import { check } from "k6";

const BASE_URL = __ENV.BASE_URL || "http://localhost:3333";

export const options = {
  scenarios: {
    ui: {
      executor: "shared-iterations",
      options: {
        browser: {
          type: "chromium",
        },
      },
    },
  },
};

export default async function () {
  const pizzaContext = browser.newContext();
  pizzaContext.addCookies([
    {
      name: "X-User-ID",
      value: 123456,
      domain: BASE_URL,
      path: '/',
    },
  ]);
  const pizzaPage = pizzaContext.newPage();
  const cookies = pizzaContext.cookies();

  await pizzaPage.goto(BASE_URL);

  check(cookies, {
    "cookie length of QuickPizza page": cookies => cookies.length === 1,
    "cookie name": cookies => cookies[0].name === "X-User-ID",
    "cookie value": cookies => cookies[0].value === "123456"
  });

  pizzaPage.close();
  pizzaContext.close();

  const anotherContext = browser.newContext();
  const anotherPage = anotherContext.newPage();
  const anotherCookies = anotherContext.cookies();

  await anotherPage.goto('https://test.k6.io/');

  check(anotherCookies, {
    "cookie length of k6 test page": anotherCookies => anotherCookies.length === 0,
  });

  anotherPage.close();
}
