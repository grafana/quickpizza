import { LoadAndCheck } from "../../shared/frontend/basic.js";
import { ServiceDisruptor } from "k6/x/disruptor";

const BASE_URL = __ENV.BASE_URL || "http://localhost:3333";

const scenarios = {
  disrupt: {
    executor: "shared-iterations",
    iterations: 1,
    exec: "disrupt",
  },
  browser: {
    executor: "constant-vus",
    vus: 1,
    duration: "30s",
    exec: "browser"
  },
};

if (__ENV.DISABLE_DISRUPT) {
  delete scenarios["disrupt"];
}

export const options = {
  scenarios,
};

export function disrupt() {
  const disruptor = new ServiceDisruptor("pizza-info", "pizza-ns");
  const targets = disruptor.targets();
  if (targets.length == 0) {
    throw new Error("expected list to have one target");
  }

  disruptor.injectHTTPFaults({ averageDelay: "1000ms" }, "40s");
}

export async function browser() {
  await LoadAndCheck(BASE_URL, false);
}
