# QuickPizza OpenTelemetry Tracing

This document explains where OpenTelemetry (OTel) instrumentation is set up in QuickPizza, and which layer produces what (spans, metrics, profiles, or forwarded baggage).

For a full list of Prometheus metric names (including the ones OTel's HTTP instrumentation feeds into Prometheus), see [metrics.md](./metrics.md).

## Two instrumentation modes: `sdk` vs `obi`

`QUICKPIZZA_OTEL_INSTRUMENTATION_MODE` picks how HTTP and business-logic traces get created:

- **`sdk`** (default): unchanged — this app's own OTel Go SDK does everything described below: it owns the TracerProvider/MeterProvider, runs `otelhttp` on every route group, and exports over OTLP.
- **`obi`**: HTTP spans and HTTP metrics are left for an [OBI](https://opentelemetry.io/docs/zero-code/obi/) (OpenTelemetry eBPF Instrumentation) sidecar to capture from *outside* the process via eBPF — no code in this app produces them. This app does not register a global `TracerProvider` and does not run `otelhttp` in this mode (see `instrumentationMode` in `pkg/http/otel.go`), since:
  - Running `otelhttp` too would duplicate the HTTP spans/metrics OBI already captures.
  - OBI's "Go Trace API" bridge (available since OBI v0.11.0) only auto-activates for a Go process when *no* SDK `TracerProvider` is registered — it then instruments calls made through OTel's plain, unregistered global tracer instead. This is how the two manual business-logic spans (`pizza-generation`, `name-generation`) still get captured in `obi` mode: `pkg/http/http.go` always calls `otel.Tracer("quickpizza")` (the global accessor) rather than deriving a tracer from the current span's provider, so in `obi` mode that resolves to the auto-instrumentable default tracer instead of a real SDK one. See https://opentelemetry.io/docs/zero-code/obi/distributed-traces/.

Go runtime metrics, Prometheus application counters, logs, and profiling are unaffected by this toggle — they keep working the same way in both modes (OBI doesn't produce any of those).

Known caveat, not yet verified live: database spans could show up twice in `obi` mode, once from OBI's own Postgres wire-protocol capture and once from its Go Trace API bridge picking up the `bunotel` query hook's own (unregistered, in `obi` mode) `Start()` calls.

To try `obi` mode locally with `compose.grafana-local-stack.monolithic.yaml`:

```sh
QUICKPIZZA_OTEL_INSTRUMENTATION_MODE=obi docker compose -f compose.grafana-local-stack.monolithic.yaml --profile obi up
```

(Without `--profile obi`, the `obi` sidecar container never starts, regardless of the env var above.)

## Setup entry point

All SDK/provider/exporter wiring lives in `pkg/http/otel.go`. `cmd/main.go` creates one `OTelInstaller` per process and, if `QUICKPIZZA_OTLP_ENDPOINT` is set, calls `NewOTelInstaller` to configure OTLP exporters; otherwise the installer is a no-op (spans/metrics are created but never exported).

`OTelInstaller.Install(router, serviceComponent, ...)` is called once per service "component" registered on the chi router (`AddFrontend`, `AddGateway`, `AddCatalogHandler`, `AddCopyHandler`, `AddRecommendations`, `AddConfigHandler`, plus `users`/`admin`/`ws` route groups). Each call:

- Sets the **global** tracer/meter providers on the *first* call only (a `TODO` in the code notes this makes the first-registered component "own" the global providers — not ideal, but this is how it currently works).
- Installs `otelhttp.NewHandler` on that router group, wrapped by two custom middlewares: `OTelRouteLabeler` (adds the resolved chi route pattern as an `http.route` attribute, since `otelhttp` can't see it before routing) and `LogTraceID` (writes the trace ID into structured logs).
- Registers Go runtime metrics (`contrib/instrumentation/runtime`) once, globally.

Resource attributes (`service.name`, `service.component`, `service.namespace`, `service.instance.id`) are set from `QUICKPIZZA_OTEL_SERVICE_*` env vars, defaulting to `quickpizza`/`quickpizza`/`local`.

## Instrumentation by layer

| Layer | Mechanism | Produces | Description |
|---|---|---|---|
| HTTP server | `otelhttp.NewHandler` (auto) | Spans, metrics | A span for every incoming HTTP request, named `METHOD /path` (e.g. `POST /api/pizza`), covering the full request lifetime. Also emits `http_server_request_duration`, `http_server_request_body_size`, and `http_server_response_body_size` metrics, labeled by method, route, and status code. |
| HTTP client (recommendations → catalog/copy) | `otelhttp.NewTransport` (auto) | Spans, metrics | A client span for every outbound HTTP call one internal service makes to another (e.g. recommendations calling catalog for ingredients). These spans are children of the request span that triggered the call, so a single pizza request produces a full call tree across services. Also emits `http_client_request_duration` metrics. |
| Database (Bun ORM) | `bunotel.NewQueryHook` (auto) | Spans | A span per SQL query (insert, select, migration, etc.), nested under whichever request or startup span triggered it. Useful for seeing exactly how much of a request's latency is spent in the database. No metrics are produced from this hook. |
| Business logic | 2 manual `otel.Tracer("quickpizza").Start()` calls | Spans | Creates a new **span**, not a new trace — it always attaches to the trace already in progress (in `sdk` mode, the one started by the `otelhttp` server span for the current request; in `obi` mode, whatever OBI is already tracking for the request). Two such spans exist: `pizza-generation`, which wraps the whole pizza-building loop inside `POST /api/pizza`, including retries when a generated pizza exceeds the calorie limit; and `name-generation`, nested inside it, which wraps just the random-name generation, including an artificial random sleep. These exist because that code has no HTTP/DB/gRPC boundary of its own for auto-instrumentation to attach to — without a manual span, that time would be invisible, folded into the parent request span with no explanation. In `obi` mode these are captured by OBI's Go Trace API bridge instead of this app's SDK — see "Two instrumentation modes" above. |
| Go runtime | `contrib/instrumentation/runtime` (auto) | Metrics | Process-level metrics: goroutine count, GC pause times, heap/stack memory usage. Not tied to any individual request or trace; useful for spotting resource pressure or leaks over time. |
| gRPC | **none** | Nothing | The gRPC server is currently uninstrumented — no spans or metrics are produced for gRPC calls (`Status`, `RatePizza`). This is a known gap, not a deliberate omission. |
| Application counters/histograms | Prometheus client (not OTel) | Metrics | Domain-specific metrics that OTel has no concept of, e.g. how many pizzas were recommended, how many ingredients/calories a pizza had, split by vegetarian/tool. Registered on the standard Prometheus client registry and exposed on `/metrics`; no OTel SDK, OTLP, or collector involvement. Included here because in a Grafana dashboard these sit right next to the real OTel HTTP metrics and look indistinguishable — in the local stack, Alloy *scrapes* `/metrics` (pull) for these, while it *receives* the OTel metrics over OTLP (push) on a completely separate pipeline; both end up converted to the same Prometheus-compatible format downstream, which is what erases the distinction unless you know to look for it. |
| Profiling | Pyroscope + `otel-profiling-go` (opt-in, off by default) | Profiles | Continuous CPU/memory profiling runs regardless. Setting `QUICKPIZZA_TRACES_LINK_PROFILES` additionally tags spans and profile samples for Tempo's "Profiles for this span" correlation — but that correlation doesn't reliably work in this app's current deployment, so it's opt-in rather than on by default. Treat it as experimental. |
| Baggage | `baggagecopy.NewSpanProcessor` (auto) | Span attributes (forwarded from baggage) | Copies any OTel baggage set on the request (arbitrary key/value context propagated across service calls) onto every span in that trace as attributes, so cross-cutting metadata (e.g. a test run ID from k6) shows up on every span without each service needing to read and re-attach it manually. Doesn't create spans itself — it enriches spans created elsewhere. |

If you add a new manual span, add a row here.

### Why traces span multiple services

In the microservices compose stack, `public-api` calls `recommendations`, which calls `catalog` and `copy` over HTTP. Because both client and server sides use the same `otelhttp` propagators (`TraceContext` + `Baggage`, set in `otel.SetTextMapPropagator`), a single trace ID flows across all four services, and a request to `/api/pizza` produces one trace with spans contributed by every service involved.

### Known limitation: span-level profile correlation

Tempo's "Profiles for this span" button doesn't reliably show per-request data in this app, even with `QUICKPIZZA_TRACES_LINK_PROFILES` enabled. `otel-profiling-go`'s own README explains why: the `pyroscope.profile.id` attribute marks a span as *eligible* for a profile, but doesn't guarantee one was collected — the CPU profiler only samples every ~10ms, so a span needs at least that much actual on-CPU time to ever get sampled. This app's request-handling code is mostly I/O-bound (waiting on catalog/copy/recommendations over HTTP) with little real CPU work per request, so individual requests rarely accumulate 10ms of on-CPU time — there's usually nothing to sample. Treat this feature as experimental rather than working.
