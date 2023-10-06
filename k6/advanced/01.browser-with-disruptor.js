import { LoadAndCheck } from "../foundations/lib/frontend/basic.js";
import { ServiceDisruptor } from "k6/x/disruptor";

const BASE_URL = __ENV.BASE_URL || "http://localhost:3333";

const scenarios = {
  disrupt: {
    executor: "shared-iterations",
    iterations: 1,
    vus: 1,
    exec: "disrupt",
  },
  browser: {
    executor: "constant-vus",
    vus: 1,
    duration: "10s",
    startTime: "10s",
    exec: "browser",
    options: {
      browser: {
        type: "chromium",
      },
    },
  },
};

if (__ENV.DISABLE_DISRUPT) {
  delete scenarios["disrupt"];
}

export const options = {
  scenarios,
};

const fault = {
  averageDelay: "1000ms",
  errorRate: 0.1,
  errorCode: 500,
}

export function disrupt() {
  const disruptor = new ServiceDisruptor("pizza-info", "pizza-ns");
  const targets = disruptor.targets();
  if (targets.length == 0) {
    throw new Error("expected list to have one target");
  }

  disruptor.injectHTTPFaults(fault, "20s");
}

export async function browser() {
  await LoadAndCheck(BASE_URL, false);
}
