# QuickPizza OpenTelemetry Tracing

This document explains where OpenTelemetry (OTel) instrumentation is set up in QuickPizza, and which layer produces what (spans, metrics, profiles, or forwarded baggage).

For a full list of Prometheus metric names (including the ones OTel's HTTP instrumentation feeds into Prometheus), see [metrics.md](./metrics.md).

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
| Business logic | 2 manual `tracer.Start()` calls | Spans | `tracer.Start()` creates a new **span**, not a new trace — it always attaches to the trace already in progress (the one started by the `otelhttp` server span for the current request). Two such spans exist: `pizza-generation`, which wraps the whole pizza-building loop inside `POST /api/pizza`, including retries when a generated pizza exceeds the calorie limit; and `name-generation`, nested inside it, which wraps just the random-name generation, including an artificial random sleep. These exist because that code has no HTTP/DB/gRPC boundary of its own for auto-instrumentation to attach to — without a manual span, that time would be invisible, folded into the parent request span with no explanation. |
| Go runtime | `contrib/instrumentation/runtime` (auto) | Metrics | Process-level metrics: goroutine count, GC pause times, heap/stack memory usage. Not tied to any individual request or trace; useful for spotting resource pressure or leaks over time. |
| gRPC | **none** | Nothing | The gRPC server is currently uninstrumented — no spans or metrics are produced for gRPC calls (`Status`, `RatePizza`). This is a known gap, not a deliberate omission. |
| Application counters/histograms | Prometheus client (not OTel) | Metrics | Domain-specific metrics that OTel has no concept of, e.g. how many pizzas were recommended, how many ingredients/calories a pizza had, split by vegetarian/tool. Registered on the standard Prometheus client registry and exposed on `/metrics`; no OTel SDK, OTLP, or collector involvement. Included here because in a Grafana dashboard these sit right next to the real OTel HTTP metrics and look indistinguishable — in the local stack, Alloy *scrapes* `/metrics` (pull) for these, while it *receives* the OTel metrics over OTLP (push) on a completely separate pipeline; both end up converted to the same Prometheus-compatible format downstream, which is what erases the distinction unless you know to look for it. |
| Profiling | Pyroscope + `otel-profiling-go` | Profiles (span-linked) | Continuous CPU/memory profiles, each linked to the trace/span that was executing at the time it was captured. This lets you jump from a slow span in Tempo directly to the profile of what the CPU was doing during it. Not a span or a metric itself — it attaches profiling data to existing spans. |
| Baggage | `baggagecopy.NewSpanProcessor` (auto) | Span attributes (forwarded from baggage) | Copies any OTel baggage set on the request (arbitrary key/value context propagated across service calls) onto every span in that trace as attributes, so cross-cutting metadata (e.g. a test run ID from k6) shows up on every span without each service needing to read and re-attach it manually. Doesn't create spans itself — it enriches spans created elsewhere. |

If you add a new manual span, add a row here.

### Why traces span multiple services

In the microservices compose stack, `public-api` calls `recommendations`, which calls `catalog` and `copy` over HTTP. Because both client and server sides use the same `otelhttp` propagators (`TraceContext` + `Baggage`, set in `otel.SetTextMapPropagator`), a single trace ID flows across all four services, and a request to `/api/pizza` produces one trace with spans contributed by every service involved.
