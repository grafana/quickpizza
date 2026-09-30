# QuickPizza OpenTelemetry Tracing

This document explains what telemetry (spans, metrics, profiles, forwarded baggage) QuickPizza produces, and where it comes from.

For a full list of Prometheus metric names (including the ones OTel's HTTP instrumentation feeds into Prometheus), see [metrics.md](./metrics.md).

## Two instrumentation modes: `sdk` vs `obi`

`QUICKPIZZA_OTEL_INSTRUMENTATION_MODE` picks how QuickPizza's telemetry gets produced, and defaults to `sdk`. The two modes are mutually exclusive alternatives, not layers that stack — pick one. Coverage is mostly the same between them, with a couple of exceptions noted below.

| Signal | `sdk` | `obi` |
|---|---|---|
| HTTP server spans/metrics | Produced by this app | Produced by [OBI](https://opentelemetry.io/docs/zero-code/obi/) (OpenTelemetry eBPF Instrumentation), from outside the process |
| HTTP client spans/metrics | Produced by this app | Produced by OBI |
| Database spans | Produced by this app, via a Bun ORM query hook | Produced by OBI, from the raw Postgres wire protocol |
| Business-logic spans (`pizza-generation`, `name-generation`) | Produced by this app | Also produced, via a different capture path — same span names and nesting |
| Go runtime metrics | Produced by this app | Produced by OBI natively |
| Request queue/processing timing | Not produced | Produced — see below |
| Resource attributes (`service.name`, ...) | Set by this app from `QUICKPIZZA_OTEL_SERVICE_*` env vars | Set by OBI, read per-process from each container's own `OTEL_SERVICE_NAME`/`OTEL_RESOURCE_ATTRIBUTES` |
| Prometheus app counters, logs, profiling | Unaffected by this toggle | Unaffected by this toggle |

To try `obi` mode:

```sh
# Local stack - monolith: one quickpizza process, one obi container attached to it.
QUICKPIZZA_OTEL_INSTRUMENTATION_MODE=obi docker compose -f compose.grafana-local-stack.monolithic.yaml --profile obi up

# Local stack - microservices: 7 separate processes (catalog/config/copy/public-api/
# recommendations/ws/grpc), one obi container discovering and attaching to all of them.
QUICKPIZZA_OTEL_INSTRUMENTATION_MODE=obi docker compose -f compose.grafana-local-stack.microservices.yaml --profile obi up

# Grafana Cloud - monolith / microservices: same as above, just exported through Alloy to
# Grafana Cloud instead of the local stack (needs GRAFANA_CLOUD_TOKEN/GRAFANA_CLOUD_STACK set).
QUICKPIZZA_OTEL_INSTRUMENTATION_MODE=obi docker compose -f compose.grafana-cloud.monolithic.yaml --profile obi up
QUICKPIZZA_OTEL_INSTRUMENTATION_MODE=obi docker compose -f compose.grafana-cloud.microservices.yaml --profile obi up
```

(Without `--profile obi`, the `obi` container(s) never start, regardless of the env var above.)

### Known differences in captured data

- **`obi` mode's HTTP spans include queueing time; `sdk` mode's structurally can't.** Each server span gets `in queue` (wait before the handler runs) and `processing` (handler execution) child spans — OBI's own docs frame this as measuring *total request time* (client-perceived) rather than just *service time* (handler-only). `sdk` mode's span only starts once the handler is invoked, so it can only ever measure service time — queueing delay is structurally invisible to it, not just unimplemented. Details: https://opentelemetry.io/docs/zero-code/obi/requesttime/.
- **`/metrics` and `/debug/pprof/*` are excluded from `obi` mode's captured spans/metrics** — these endpoints were never traced in `sdk` mode either, so this exclusion keeps the two modes' data comparable rather than flooding `obi` mode with scrape traffic `sdk` mode never showed.
- **Database spans look different between modes.** `sdk` mode's DB spans carry the formatted SQL query text as an attribute; `obi` mode's DB spans, being derived from the wire protocol, may not carry the same level of query detail.
- **Prometheus HTTP request metrics lose their trace-linking exemplar in `obi` mode.** The request counter/duration metrics themselves are recorded identically in both modes (see "HTTP request metrics (Prometheus)" below), but the `trace_id` exemplar that lets you jump from a slow bucket to its trace is only attached in `sdk` mode.

## Instrumentation by layer

| Layer | Produces | Description |
|---|---|---|
| HTTP server | Spans, metrics | A span for every incoming HTTP request, named `METHOD /path` (e.g. `POST /api/pizza`), covering the full request lifetime. Also emits `http_server_request_duration`, `http_server_request_body_size`, and `http_server_response_body_size` metrics, labeled by method, route, and status code. Uses current HTTP semantic convention attribute names (`http.request.method`, `url.path`). |
| HTTP client (recommendations → catalog/copy, and the gateway's reverse proxy) | Spans, metrics | A client span for every outbound HTTP call one internal service makes to another (e.g. recommendations calling catalog for ingredients). These spans are children of the request span that triggered the call, so a single pizza request produces a full call tree across services. Also emits `http_client_request_duration` metrics. |
| Database | Spans | A span per SQL query (insert, select, migration, etc.), nested under whichever request or startup span triggered it. Useful for seeing exactly how much of a request's latency is spent in the database. No metrics are produced from this layer. |
| Business logic | Spans | Two manual spans, nested inside `POST /api/pizza`'s request span (not a new trace): `pizza-generation`, which wraps the whole pizza-building loop, including retries when a generated pizza exceeds the calorie limit; and `name-generation`, nested inside it, which wraps just the random-name generation, including an artificial random sleep. Without these, that time would be invisible, folded into the parent request span with no explanation. |
| Go runtime | Metrics | Process-level metrics: goroutine count, GC pause times, heap/stack memory usage, CPU time. Not tied to any individual request or trace; useful for spotting resource pressure or leaks over time. |
| gRPC | Nothing | The gRPC server is currently uninstrumented — no spans or metrics are produced for gRPC calls (`Status`, `RatePizza`), in either mode. This is a known gap, not a deliberate omission. |
| HTTP request metrics (Prometheus) | Metrics | A request counter plus three duration metrics (histogram, native histogram, gauge), labeled by method, route, and status. Recorded unconditionally in *both* `sdk` and `obi` mode — independent of the instrumentation-mode toggle. In `sdk` mode these also carry a `trace_id` exemplar linking a bucket back to the specific trace that produced it; in `obi` mode no trace ID ever reaches this code path, so the same metrics get recorded but never an exemplar. |
| Application counters/histograms | Metrics | Domain-specific metrics that OTel has no concept of, e.g. how many pizzas were recommended, how many ingredients/calories a pizza had, split by vegetarian/tool. Exposed on `/metrics` via the standard Prometheus client, entirely separate from OTel/OTLP. Included here because in a Grafana dashboard these sit right next to the real OTel HTTP metrics and look indistinguishable — in the local stack, Alloy *scrapes* `/metrics` (pull) for these, while it *receives* the OTel metrics over OTLP (push) on a completely separate pipeline; both end up converted to the same Prometheus-compatible format downstream, which is what erases the distinction unless you know to look for it. |
| Profiling | Profiles | Continuous CPU/memory profiling via Pyroscope, independent of tracing mode. Setting `QUICKPIZZA_TRACES_LINK_PROFILES` additionally tags spans and profile samples for Tempo's "Profiles for this span" correlation — but that correlation doesn't reliably show data in this app's current deployment (see below), so it's opt-in rather than on by default. |
| Baggage | Span attributes | `sdk` mode only. Any OTel baggage set on a request (arbitrary key/value context propagated across service calls, e.g. a test run ID from k6) is copied onto every span in that trace as attributes, via a span processor this app's own SDK registers — so it shows up everywhere in the trace without each service needing to read and re-attach it manually. `obi` mode has no equivalent: OBI doesn't copy W3C baggage into span attributes, so baggage set on a request in `obi` mode won't show up on its spans at all. |
| Logs | Log attributes | Every log line gets a `user` attribute when authenticated. In `sdk` mode, lines written during an active span also get a `trace_id` attribute, added by this app's own code. In `obi` mode this app adds no such attribute at all — trace correlation, if any, comes from OBI's own log enricher injecting `trace_id`/`span_id` directly into the raw log bytes. |

If you add a new manual span, add a row here.

### Why traces span multiple services

In the microservices compose stack, `public-api` calls `recommendations`, which calls `catalog` and `copy` over HTTP. A single trace ID flows across all four services regardless of instrumentation mode, so a request to `/api/pizza` produces one trace with spans contributed by every service involved — in `sdk` mode via shared trace-context propagation headers, in `obi` mode via OBI's own tracking of context across service calls.

### Known limitation: span-level profile correlation

Tempo's "Profiles for this span" button doesn't reliably show per-request data in this app, even with `QUICKPIZZA_TRACES_LINK_PROFILES` enabled. The `pyroscope.profile.id` attribute marks a span as *eligible* for a profile, but doesn't guarantee one was collected — the CPU profiler only samples every ~10ms, so a span needs at least that much actual on-CPU time to ever get sampled. This app's request-handling code is mostly I/O-bound (waiting on catalog/copy/recommendations over HTTP) with little real CPU work per request, so individual requests rarely accumulate 10ms of on-CPU time — there's usually nothing to sample. Treat this feature as experimental rather than working.
