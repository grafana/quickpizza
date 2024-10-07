import { browser } from "k6/browser";
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
  const pizzaContext = await browser.newContext();
  await pizzaContext.addCookies([
    {
      name: "X-User-ID",
      value: 123456,
      domain: BASE_URL,
      path: '/',
    },
  ]);
  const pizzaPage = await pizzaContext.newPage();
  const cookies = await pizzaContext.cookies();

  await pizzaPage.goto(BASE_URL);

  check(cookies, {
    "cookie length of QuickPizza page": cookies => cookies.length === 1,
    "cookie name": cookies => cookies[0].name === "X-User-ID",
    "cookie value": cookies => cookies[0].value === "123456"
  });

  await pizzaPage.close();
  await pizzaContext.close();

  const anotherContext = await browser.newContext();
  const anotherPage = await anotherContext.newPage();
  const anotherCookies = await anotherContext.cookies();

  await anotherPage.goto('https://test.k6.io/');

  check(anotherCookies, {
    "cookie length of k6 test page": anotherCookies => anotherCookies.length === 0,
  });

  await anotherPage.close();
}
