# QuickPizza — k6 workshop

A stripped-down fork of [grafana/quickpizza](https://github.com/grafana/quickpizza),
used as the system under test for a hands-on k6 workshop.

Upstream QuickPizza is a full observability demo: browser tests, xk6 extensions, gRPC,
WebSockets, Kubernetes, Terraform, Alloy, Tempo, Loki, Pyroscope. All of that has been
removed here on purpose. What is left is one application, one `compose.yaml`, and three
k6 scripts covering the three test types the workshop is about.

If you want any of the removed material, go to the upstream repository.

## What the workshop covers

| Test type | Script | Question it answers |
|---|---|---|
| **Smoke** | `k6/01-smoke.js` | Does the system work at all under minimal load? |
| **Load** (performance) | `k6/02-load.js` | Does it meet its performance targets under expected traffic? |
| **Spike** (peak load) | `k6/03-spike.js` | What happens at a sudden peak, and does it recover? |

Plus the three things that turn a script into a test: **checks**, **custom metrics** and
**thresholds**.

## Requirements

- Docker (with Compose)
- [k6](https://grafana.com/docs/k6/latest/set-up/install-k6/) — `brew install k6`

```bash
git clone --depth 1 <this-repo>
```

`--depth 1` is worth it: the full history carries ~164 MB of vendored Go dependencies
that the workshop never touches.

Nothing else. You do not need Go or Node — `compose.yaml` runs a published image.

## Quick start

```bash
make up      # QuickPizza + Postgres + Prometheus + Grafana
make smoke   # 30 seconds
```

| | |
|---|---|
| QuickPizza | http://localhost:3333 |
| Grafana | http://localhost:3000 (no login) |
| Prometheus | http://localhost:9090 |

If a port is taken, override it:

```bash
GRAFANA_PORT=3001 PROMETHEUS_PORT=9091 QUICKPIZZA_PORT=8080 make up
make smoke QUICKPIZZA_PORT=8080
```

`make down` when you are finished. `make help` lists every target.

## Running the tests

```bash
make smoke   # 1 VU, 30s
make load    # ramp to 10 VUs, ~2 min
make spike   # peak of 100 VUs, ~2 min
```

All three hit the same endpoint (`POST /api/pizza`) with the same user journey. They
differ only in the **shape of the load** (`k6/lib/stages.js`) and in the **expectations**
attached to it. That is the main idea of the walkthrough: a test type is a traffic
profile plus a set of thresholds, not a different kind of script.

## Checks

A `check` is an assertion about a response:

```js
check(res, {
  "status is 200": (r) => r.status === 200,
  "no excluded ingredient was used": () => /* ... */,
});
```

Two things surprise people:

1. **A failing check does not fail the test.** It is recorded and the iteration carries
   on. This is deliberate — under load you want the full picture, not a stop at the
   first error.
2. **What makes checks a gate is a threshold on the `checks` metric.** k6 aggregates
   every check into one pass rate; `checks: ["rate>0.99"]` is what turns assertions into
   a build decision.

Worth pointing at: status codes alone are a weak assertion. A service under load can
stay fast and still return wrong answers, which is why these scripts also assert
business rules (the recipe must respect the restrictions we sent).

## Metrics

k6 collects these for free; the ones that matter most:

| Metric | Type | What it is |
|---|---|---|
| `http_req_duration` | Trend | End-to-end response time. Look at `p(95)`/`p(99)`, not `avg`. |
| `http_req_failed` | Rate | Share of failed requests — your error rate. |
| `checks` | Rate | Share of checks that passed. |
| `iterations` | Counter | Completed runs of the default function. |
| `vus` | Gauge | Virtual users currently active. |

**Never set a target on the average.** An average hides the slow tail, which is exactly
what users complain about. Percentiles are the whole point.

You add your own for anything domain-specific — `k6/02-load.js` declares two:

```js
const pizzasCreated = new Counter("pizzas_created");  // only goes up
const pizzaCalories = new Trend("pizza_calories");    // full distribution
```

Four types exist: `Counter`, `Gauge`, `Rate` and `Trend`.

## Thresholds

Thresholds are the pass/fail criteria — where SLOs stop being a slide and become a build
step:

```js
thresholds: {
  http_req_failed: ["rate<0.01"],              // availability
  http_req_duration: ["p(95)<500", "p(99)<1000"], // latency
  checks: ["rate>0.99"],                       // correctness
  pizza_calories: ["max<=500"],                // your own domain
}
```

A breached threshold makes k6 exit with **code 99**, so CI fails without any extra
scripting:

```bash
k6 run k6/02-load.js ; echo $?    # -> 99 when a threshold is crossed
```

(Through `make` you will see `make: *** [load] Error 99` in the output, but `$?` is 2 —
make reports its own exit code, not the recipe's. Call `k6 run` directly when the exit
code itself is the point.)

Compare the three scripts: the smoke test demands `rate==0` failures, the spike test
tolerates `rate<0.05`. Same system, different expectations — because degrading under a
20x spike is acceptable and falling over is not.

## Watching results in Grafana

Stream results into the local Prometheus while the test runs:

```bash
make load K6_FLAGS="-o experimental-prometheus-rw"
```

Then open Grafana → **k6 Prometheus**. The panels fill in live.

Each run is tagged (`smoke-<timestamp>`, `load-<timestamp>`, …) so you can pick it from
the dashboard's test-run dropdown and compare runs side by side. The `make` targets add
that tag for you; if you call `k6 run` by hand, pass `--tag testid=something` or the
dashboard will have nothing to select.

Prometheus also scrapes QuickPizza's own `/metrics`, so in **Explore** you can compare
the two sides of the same traffic:

- `k6_http_req_duration_p99` — what the client experienced
- `quickpizza_server_http_request_duration_seconds` — what the server thinks it did

The gap between them is queueing, connection setup and network. Good material for the
"where did the time actually go?" conversation.

No Docker needed for a quick look — k6 ships its own dashboard:

```bash
make load K6_FLAGS="--out web-dashboard"
```

## Making a test fail on purpose

A test that always passes demonstrates nothing. Uncomment one of the fault-injection
variables on the `quickpizza` service in [`compose.yaml`](compose.yaml) and `make up`
again:

```yaml
QUICKPIZZA_DELAY_RECOMMENDATIONS_API_PIZZA_POST: "800ms"
```

`make load` now breaches `p(95)<500` and `p(99)<1000` (response time goes from ~130 ms
to ~940 ms), while the application itself stays perfectly healthy — a clean illustration
that a threshold is a decision you made, not a property of the system. See
[docs/inject-errors.md](docs/inject-errors.md) for the full list, including error rates
and timeouts.

## Cheat sheet

```bash
make load K6_FLAGS="--vus 50 --duration 1m"          # override the load profile
make load K6_FLAGS="--summary-mode=full"             # per-group/per-check detail
make load K6_FLAGS="--summary-export=summary.json"   # machine-readable summary
make load K6_FLAGS="--no-thresholds"                 # measure without gating
make load K6_FLAGS="--http-debug=full"               # dump requests and responses
make smoke BASE_URL=https://my-env.example.com       # point at another environment
```

## Layout

```
k6/
├── 01-smoke.js   02-load.js   03-spike.js
├── lib/config.js   shared BASE_URL, auth header, request payload
├── lib/stages.js   the three load profiles
└── README.md       facilitator notes for the walkthrough
compose.yaml                     the workshop stack
deployments/observability/       Prometheus config + provisioned Grafana dashboards
docs/inject-errors.md            how to make things fail
quickpizza-openapi.yaml          the full API, if you want to script another endpoint
cmd/ pkg/                        the Go application and SvelteKit frontend
```
