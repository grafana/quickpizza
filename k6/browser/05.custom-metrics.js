import { browser } from "k6/experimental/browser";
import { check } from "k6";
import { Trend } from "k6/metrics";

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
  thresholds: {
    browser_web_vital_fcp: ["p(95) < 1000"],
    browser_web_vital_lcp: ["p(95) < 2000"],
    checks: ["rate > 0.9"]
  }
};

const myTrend = new Trend('totalActionTime');

export default async function () {
  const page = browser.newPage();

  try {
    await page.goto(BASE_URL);
    page.evaluate(() => window.performance.mark('page-visit'));

    check(page, {
      header:
        page.locator("h1").textContent() ==
        "Looking to break out of your pizza routine?",
    });

    await page.locator('//button[. = "Pizza, Please!"]').click();
    page.waitForTimeout(500);
    page.evaluate(() => window.performance.mark('recommendations-returned'));

    page.screenshot({ path: "screenshot.png" });
    check(page, {
      recommendation: page.locator("div#recommendations").textContent() != "",
    });

    //Get time difference between visiting the page and pizza recommendations returned
    page.evaluate(() =>
      window.performance.measure(
        'total-action-time',
        'page-visit',
        'recommendations-returned',
      )
    );

    const totalActionTime = page.evaluate(() =>
      JSON.parse(JSON.stringify(window.performance.getEntriesByName('total-action-time')))[0].duration
    );

    myTrend.add(totalActionTime);
  } finally {
    page.close();
  }
}
