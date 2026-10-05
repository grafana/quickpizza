# Facilitator notes

Running order for the walkthrough. Total runtime is about five minutes, so each test can
be launched and discussed while it runs.

Before you start: `make up`, then open http://localhost:3333 and click **Pizza, Please!**
once. Everybody has now seen the single request the three tests are about to hammer.

---

## 01-smoke.js — 30 seconds

```bash
make smoke
```

**Point at, in the script:**

- `options` — `vus: 1`, `duration: "30s"`. The entire load profile is two lines.
- `setup()` — runs once before any VU. It fails fast with a readable message instead of
  burying people in connection errors. Note it is the reason `http_reqs` is one higher
  than `iterations`.
- `check()` — two assertions, and the fact that a failing one would *not* stop anything.
- `thresholds` — `rate==0` and `rate==1`. At this load nothing is allowed to fail.

**Point at, in the summary:**

- The `THRESHOLDS` block at the top: three green ticks. This is the test's verdict.
- `checks_succeeded: 100.00%` and the per-check breakdown underneath.
- `http_req_duration` — read out `avg`, then `p(95)`. Ask which one you would put in an
  SLO. (Expect roughly 120 ms avg, 300 ms p95 on a laptop.)
- `iterations ≈ 27`, not 30 — because `sleep(1)` plus a ~130 ms request is more than one
  second per iteration. Good moment to say that VUs are not requests per second.

---

## 02-load.js — about 2 minutes

```bash
make load K6_FLAGS="-o experimental-prometheus-rw"
```

Launch it, switch to Grafana → **k6 Prometheus**, and talk over the live panels.

**Point at, in the script:**

- `stages` — ramp up, hold, ramp down. The plateau is the part you measure; the ramps
  exist so you do not shock the system.
- `Counter` vs `Trend`. A counter answers "how many", a trend answers "how slow, at which
  percentile". k6 gives you the percentiles for free.
- The two business-rule checks. This is the shift from "did it respond" to "was it
  right" — the point worth labouring for a QE audience.
- `thresholds` now has four entries covering availability, latency, correctness and one
  domain metric.

**Point at, in the summary:**

- The `CUSTOM` section: `pizzas_created` and `pizza_calories` sit next to the built-in
  metrics and are thresholded the same way.
- `checks_succeeded` will be around **99.9%, not 100%** — and the test still passes. Walk
  through why below; it is the best teaching moment in the whole session.

### Why the calorie check misses ~0.4% of the time

QuickPizza generates a recipe, checks whether it is under the calorie cap, and retries if
not — but only **10 times** (`pkg/http/http.go:1479`). After that it returns the
over-budget pizza anyway. So "calories within the requested limit" is a *best-effort*
guarantee, not an invariant.

That is why `02-load.js` sets `checks: ["rate>0.99"]` instead of `rate==1`, and why
`01-smoke.js` does not include this check at all: with ~27 iterations and `rate==1`, the
smoke test would fail spuriously about one run in ten.

The lesson: **a threshold is an error budget you chose, not a measurement.** Before you
can set one, you have to know which of your assertions are guaranteed and which are best
effort. Most teams find that out in production.

---

## 03-spike.js — about 2 minutes

```bash
make spike K6_FLAGS="-o experimental-prometheus-rw"
```

**Point at, in the script:**

- The script body is **character-for-character the same journey** as the load test. Only
  `stages` and `thresholds` changed. Say this out loud — it is the thesis of the session.
- `SPIKE_STAGES` in `lib/stages.js`: baseline → 20x jump → back to baseline. Returning to
  the baseline is deliberate; recovery is half of what a spike test measures.
- Thresholds are looser: `rate<0.05`, `p(95)<2000`. Degrading under a 20x spike is
  acceptable; not recovering is not.

**Point at, in Grafana, during the run:**

- Response time climbing as VUs jump, then coming back down. Compare the two baseline
  segments, before and after the peak — if the second is worse, the system did not
  recover.
- `vus` against `http_reqs`: throughput does not scale linearly with virtual users.

On a laptop QuickPizza usually survives 100 VUs comfortably. If it does, say so and move
to the next section rather than pretending otherwise — then force the failure.

---

## Finale: make it fail

```yaml
# compose.yaml, quickpizza service
QUICKPIZZA_DELAY_RECOMMENDATIONS_API_PIZZA_POST: "800ms"
```

```bash
make up
k6 run -e BASE_URL=http://localhost:3333 k6/02-load.js ; echo "exit code: $?"
```

Response time goes from ~130 ms to ~940 ms, `p(95)<500` and `p(99)<1000` both go red,
and k6 exits **99**. The application is perfectly healthy — it is just slower than the
budget you declared. That exit code is the whole reason k6 works as a CI quality gate,
and it is the right note to end on: the test did not discover that the system is broken,
it discovered that the system no longer meets an agreed target.

Call `k6 run` directly here rather than `make load`. Make prints
`make: *** [load] Error 99` so the 99 is visible either way, but `$?` would be 2 — make
reports its own exit code, not the recipe's.

Remember to comment the variable out again afterwards.

See [../docs/inject-errors.md](../docs/inject-errors.md) for error rates and timeouts.

---

## If someone asks

**"Why not use the average?"** It hides the tail. Show `avg` next to `p(99)` in any
summary; they are usually 3-4x apart.

**"How many VUs is realistic?"** VUs are not throughput. With `sleep(1)` each VU does
slightly under one iteration per second, so 10 VUs is roughly 7 req/s here — visible in
`http_reqs`. If you need a fixed request rate instead of a fixed user count, that is the
`constant-arrival-rate` executor.

**"Where did `excludedIngredients` go wrong?"** QuickPizza matches exclusions against
ingredient names **exactly**, so `"pepperoni"` excludes nothing and `"Pepperoni"` works
(see the comment in `lib/config.js`). The API accepts both without complaint. A request
the server accepts is not the same as a request the server honours — and only a check on
the response body catches it.

**"Can k6 do browser testing / gRPC / WebSockets?"** Yes, all of it. Those examples were
removed from this fork to keep the session focused; they live in
[grafana/quickpizza](https://github.com/grafana/quickpizza).
