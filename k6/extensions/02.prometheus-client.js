import { check, sleep } from "k6";
import remote from "k6/x/remotewrite";
import exec from "k6/execution";

// Performance test a Prometheus RW endpoint: https://github.com/grafana/xk6-client-prometheus-remote
// xk6 build --with github.com/grafana/xk6-client-prometheus-remote@latest
export const options = {
  scenarios: {
    contacts: {
      executor: "constant-arrival-rate",
      duration: "10s",

      // 100 iters/s = (1 req per iter) = 100 reqs/s
      rate: 100,
      timeUnit: "1s",

      preAllocatedVUs: 100,
    },
  },
};

const client = new remote.Client({
  url: __ENV.RW_URL || "http://localhost:9090/api/v1/write",
});

export default function () {
  let res = client.store([
    {
      labels: [
        { name: "__name__", value: `my_cool_metric_${exec.vu.idInTest}` },
        { name: "service", value: "bar" },
      ],
      samples: [{ value: Math.random() * 100 }],
    },
  ]);

  check(res, {
    "Status OK - 204 No Content": (r) => r.status === 204,
  });
}
