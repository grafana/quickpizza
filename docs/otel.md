# QuickPizza OpenTelemetry Tracing

This document explains where OpenTelemetry (OTel) instrumentation is set up in QuickPizza, and which layer produces what (spans, metrics, profiles, or forwarded baggage).

For a full list of Prometheus metric names (including the ones OTel's HTTP instrumentation feeds into Prometheus), see [metrics.md](./metrics.md).

## Two instrumentation modes: `sdk` vs `obi`

`QUICKPIZZA_OTEL_INSTRUMENTATION_MODE` picks how this app produces telemetry, and defaults to `sdk` (unchanged behavior). The two modes are mutually exclusive alternatives, not layers that stack: pick one.

| Signal | `sdk` | `obi` |
|---|---|---|
| HTTP server spans/metrics | `otelhttp` | [OBI](https://opentelemetry.io/docs/zero-code/obi/) (eBPF) |
| HTTP client spans/metrics | `otelhttp` | OBI (eBPF) |
| Database spans | `bunotel` query hook | OBI (Postgres wire protocol) |
| Business-logic spans (`pizza-generation`, `name-generation`) | this app's own registered `TracerProvider` | OBI's Go Trace API bridge |
| Go runtime metrics | `contrib/instrumentation/runtime` | OBI (native) |
| Resource attributes (`service.name`, ...) | `QUICKPIZZA_OTEL_SERVICE_*` env vars | `OTEL_SERVICE_NAME`/`OTEL_RESOURCE_ATTRIBUTES`, read by OBI from the `quickpizza` container's own environment |
| Prometheus app counters, logs, profiling | unaffected | unaffected |

To try `obi` mode locally with `compose.grafana-local-stack.monolithic.yaml`:

```sh
QUICKPIZZA_OTEL_INSTRUMENTATION_MODE=obi docker compose -f compose.grafana-local-stack.monolithic.yaml --profile obi up
```

(Without `--profile obi`, the `obi` sidecar container never starts, regardless of the env var above.)

### `sdk` mode

This is the default, and behaves exactly as it always has: this app's own OTel Go SDK owns everything.

`OTelInstaller.Install(router, serviceComponent, ...)` (`pkg/http/otel-sdk.go`'s `installSDK`) is called once per service "component" registered on the chi router (`AddFrontend`, `AddGateway`, `AddCatalogHandler`, `AddCopyHandler`, `AddRecommendations`, `AddConfigHandler`, plus `users`/`admin`/`ws` route groups). Each call:

- Sets the **global** tracer/meter providers on the *first* call only (a `TODO` in the code notes this makes the first-registered component "own" the global providers — not ideal, but this is how it currently works).
- Installs `otelhttp.NewHandler` on that router group, wrapped by two custom middlewares: `OTelRouteLabeler` (adds the resolved chi route pattern as an `http.route` attribute, since `otelhttp` can't see it before routing) and `LogTraceID` (writes the trace ID into structured logs).
- Registers Go runtime metrics (`contrib/instrumentation/runtime`) once, globally.

Resource attributes (`service.name`, `service.component`, `service.namespace`, `service.instance.id`) are set from `QUICKPIZZA_OTEL_SERVICE_*` env vars, defaulting to `quickpizza`/`quickpizza`/`local`.

Because both client and server sides use the same `otelhttp` propagators (`TraceContext` + `Baggage`, set in `otel.SetTextMapPropagator`), a single trace ID flows across every service a request touches — in the microservices compose stack, a request to `/api/pizza` produces one trace spanning `public-api` → `recommendations` → `catalog`/`copy`.

### `obi` mode

`installOBI` (`pkg/http/otel-obi.go`) is a deliberate no-op: this app registers no `TracerProvider`, no `MeterProvider`, and runs no `otelhttp`. [OBI](https://opentelemetry.io/docs/zero-code/obi/) (OpenTelemetry eBPF Instrumentation) captures all of it from *outside* the process via eBPF instead, with zero app-side code — HTTP spans/metrics and even Go runtime metrics (goroutine count, GC, memory, CPU, scheduling; see https://opentelemetry.io/docs/zero-code/obi/metrics/). Running any of this app's own OTel SDK code here too would just duplicate what OBI already captures.

**Business-logic spans still get captured, through a separate mechanism.** OBI's "Go Trace API" bridge (available since OBI v0.11.0) only auto-activates for a Go process when *no* SDK `TracerProvider` is registered — it then instruments calls made through OTel's plain, unregistered global tracer instead (see https://opentelemetry.io/docs/zero-code/obi/distributed-traces/). `BusinessTracer` (`pkg/http/otel.go`) is what `pkg/http/http.go`'s `AddRecommendations` uses for the `pizza-generation`/`name-generation` spans; in `obi` mode it always returns `otel.Tracer("quickpizza")` (the global accessor) instead of deriving a tracer from the current request's span. This isn't a style choice — in `obi` mode there's no span in `ctx` to derive one from anyway (no `otelhttp` ever runs), and the fallback path an empty context resolves to is a *different*, permanently no-op tracer that OBI's bridge doesn't hook. See `BusinessTracer`'s own doc comment in `pkg/http/otel.go` for the full mechanism.

**Database spans need the same care, for a different reason.** `pkg/database`'s `bunotel` query hook calls into the OTel API internally, through that same unregistered global tracer — so without a gate, every query would get captured twice: once by OBI's own Postgres wire-protocol capture, once by OBI's Go Trace API bridge picking up `bunotel`'s own call. `InstrumentDatabase()` (`pkg/http/otel.go`) reports `false` in `obi` mode; `cmd/main.go` passes it into `database.NewCatalog`/`database.NewCopy`, which thread it down to `initializeDB` as `enableOTelSpanQueryHook`. Confirmed live: DB span counts match real query volume 1:1 with the gate in place.

**Resource attributes** aren't set by this app at all in `obi` mode — OBI reads `OTEL_SERVICE_NAME` and `OTEL_RESOURCE_ATTRIBUTES` directly out of the `quickpizza` container's own environment (already set there for `sdk` mode's benefit) to label what it captures.

**Context propagation across services** is OBI's own job too: this app sets no propagator in `obi` mode, and OBI tracks and correlates context across service calls itself, from eBPF observations (see https://opentelemetry.io/docs/zero-code/obi/context-propagation/).

**Two gotchas worth knowing about when running this locally**, both found by actually running it against the local stack:

- `deployments/docker-compose/grafana-local-stack/config.alloy`'s pipeline is shared by both modes — both this app's SDK and OBI point at the same `http://alloy:4318`. Its `otelcol.connector.servicegraph` connector was configured with the *old* HTTP semantic convention attribute names (`http.method`/`http.target`), which don't exist on spans from either source with the currently vendored/pulled library versions. This wasn't `obi`-specific — it was already silently broken in `sdk` mode too, just surfaced while testing `obi` mode. Fixed to `["http.request.method", "url.path"]`.
- OBI captures noisy infrastructure endpoints (`/metrics`, `/debug/pprof/*`) that this app's own SDK never sent traces for in the first place — they're registered outside any `router.Group()`/`Install()` block (see `isInternalRoute` in `pkg/http/http.go`), which has zero effect on OBI since it operates at the socket level, independent of the app's router structure. `deployments/docker-compose/grafana-local-stack/obi.yaml` (mounted into the `obi` container via `-config`) mirrors that exclusion for OBI's own capture.

## Setup entry point

SDK/provider/exporter wiring is split across three files in `pkg/http/`, by instrumentation mode:

- `otel.go` — shared code: the `OTelInstaller` type, `InstrumentationMode`, `Install` (dispatches to one of the two files below), and the two helpers mode-aware callers outside `Install`'s own dispatch use instead of checking the mode themselves: `NewOTelHTTPTransport` (for HTTP clients built outside `Install`) and `BusinessTracer` (for manual business-logic spans). `InstrumentDatabase` also lives here, for `pkg/database` to check.
- `otel-sdk.go` — the `sdk` mode implementation: resource/protocol env var parsing, trace and metric providers/exporters, `otelhttp`, `OTelRouteLabeler`, `LogTraceID`.
- `otel-obi.go` — the `obi` mode implementation: a single-function no-op (`installOBI`).

`cmd/main.go` creates one `OTelInstaller` per process and, if `QUICKPIZZA_OTLP_ENDPOINT` is set, calls `NewOTelInstaller` to configure OTLP exporters; otherwise the installer is a no-op (spans/metrics are created but never exported). It also calls `qphttp.InstrumentDatabase()` when constructing the catalog/copy database connections, and `qphttp.NewOTelHTTPTransport` for the recommendations→catalog/copy HTTP client.

## Instrumentation by layer

| Layer | Mechanism | Produces | Description |
|---|---|---|---|
| HTTP server | `otelhttp.NewHandler` | Spans, metrics | A span for every incoming HTTP request, named `METHOD /path` (e.g. `POST /api/pizza`), covering the full request lifetime. Also emits `http_server_request_duration`, `http_server_request_body_size`, and `http_server_response_body_size` metrics, labeled by method, route, and status code. |
| HTTP client (recommendations → catalog/copy, and the gateway's reverse proxy) | `otelhttp.NewTransport`, via the shared `NewOTelHTTPTransport` helper | Spans, metrics | A client span for every outbound HTTP call one internal service makes to another (e.g. recommendations calling catalog for ingredients). These spans are children of the request span that triggered the call, so a single pizza request produces a full call tree across services. Also emits `http_client_request_duration` metrics. |
| Database (Bun ORM) | `bunotel.NewQueryHook` | Spans | A span per SQL query (insert, select, migration, etc.), nested under whichever request or startup span triggered it. Useful for seeing exactly how much of a request's latency is spent in the database. No metrics are produced from this hook. |
| Business logic | 2 manual `tracer.Start()` calls, via the shared `BusinessTracer` helper | Spans | Creates a new **span**, not a new trace — it always attaches to the trace already in progress. Two such spans exist: `pizza-generation`, which wraps the whole pizza-building loop inside `POST /api/pizza`, including retries when a generated pizza exceeds the calorie limit; and `name-generation`, nested inside it, which wraps just the random-name generation, including an artificial random sleep. These exist because that code has no HTTP/DB/gRPC boundary of its own for auto-instrumentation to attach to — without a manual span, that time would be invisible, folded into the parent request span with no explanation. |
| Go runtime | `contrib/instrumentation/runtime` | Metrics | Process-level metrics: goroutine count, GC pause times, heap/stack memory usage. Not tied to any individual request or trace; useful for spotting resource pressure or leaks over time. |
| gRPC | **none** | Nothing | The gRPC server is currently uninstrumented — no spans or metrics are produced for gRPC calls (`Status`, `RatePizza`). This is a known gap, not a deliberate omission. |
| Application counters/histograms | Prometheus client (not OTel) | Metrics | Domain-specific metrics that OTel has no concept of, e.g. how many pizzas were recommended, how many ingredients/calories a pizza had, split by vegetarian/tool. Registered on the standard Prometheus client registry and exposed on `/metrics`; no OTel SDK, OTLP, or collector involvement. Included here because in a Grafana dashboard these sit right next to the real OTel HTTP metrics and look indistinguishable — in the local stack, Alloy *scrapes* `/metrics` (pull) for these, while it *receives* the OTel metrics over OTLP (push) on a completely separate pipeline; both end up converted to the same Prometheus-compatible format downstream, which is what erases the distinction unless you know to look for it. |
| Profiling | Pyroscope + `otel-profiling-go` (opt-in, off by default) | Profiles | Continuous CPU/memory profiling runs regardless. Setting `QUICKPIZZA_TRACES_LINK_PROFILES` additionally tags spans and profile samples for Tempo's "Profiles for this span" correlation — but that correlation doesn't reliably work in this app's current deployment, so it's opt-in rather than on by default. Treat it as experimental. |
| Baggage | `baggagecopy.NewSpanProcessor` | Span attributes (forwarded from baggage) | Copies any OTel baggage set on the request (arbitrary key/value context propagated across service calls) onto every span in that trace as attributes, so cross-cutting metadata (e.g. a test run ID from k6) shows up on every span without each service needing to read and re-attach it manually. Doesn't create spans itself — it enriches spans created elsewhere. |

If you add a new manual span, add a row here.

### Known limitation: span-level profile correlation

Tempo's "Profiles for this span" button doesn't reliably show per-request data in this app, even with `QUICKPIZZA_TRACES_LINK_PROFILES` enabled. `otel-profiling-go`'s own README explains why: the `pyroscope.profile.id` attribute marks a span as *eligible* for a profile, but doesn't guarantee one was collected — the CPU profiler only samples every ~10ms, so a span needs at least that much actual on-CPU time to ever get sampled. This app's request-handling code is mostly I/O-bound (waiting on catalog/copy/recommendations over HTTP) with little real CPU work per request, so individual requests rarely accumulate 10ms of on-CPU time — there's usually nothing to sample. Treat this feature as experimental rather than working.
