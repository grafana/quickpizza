# QuickPizza OpenTelemetry Tracing

This document explains where OpenTelemetry (OTel) instrumentation is set up in QuickPizza, which layer produces which spans and metrics, and how to verify traces are actually being exported.

For a full list of Prometheus metric names (including the ones OTel's HTTP instrumentation feeds into Prometheus), see [metrics.md](./metrics.md).

## Setup entry point

All SDK/provider/exporter wiring lives in `pkg/http/otel.go`. `cmd/main.go` creates one `OTelInstaller` per process and, if `QUICKPIZZA_OTLP_ENDPOINT` is set, calls `NewOTelInstaller` to configure OTLP exporters; otherwise the installer is a no-op (spans/metrics are created but never exported).

`OTelInstaller.Install(router, serviceComponent, ...)` is called once per service "component" registered on the chi router (`AddFrontend`, `AddGateway`, `AddCatalogHandler`, `AddCopyHandler`, `AddRecommendations`, `AddConfigHandler`, plus `users`/`admin`/`ws` route groups). Each call:

- Sets the **global** tracer/meter providers on the *first* call only (a `TODO` in the code notes this makes the first-registered component "own" the global providers — not ideal, but this is how it currently works).
- Installs `otelhttp.NewHandler` on that router group, wrapped by two custom middlewares: `OTelRouteLabeler` (adds the resolved chi route pattern as an `http.route` attribute, since `otelhttp` can't see it before routing) and `LogTraceID` (writes the trace ID into structured logs).
- Registers Go runtime metrics (`contrib/instrumentation/runtime`) once, globally.

Resource attributes (`service.name`, `service.component`, `service.namespace`, `service.instance.id`) are set from `QUICKPIZZA_OTEL_SERVICE_*` env vars, defaulting to `quickpizza`/`quickpizza`/`local`.

## Instrumentation by layer

| Layer | Mechanism | What it produces | Code |
|---|---|---|---|
| HTTP server | `otelhttp.NewHandler` (auto) | One span per request (`METHOD /path`), `http_server_request_duration` / `_body_size` metrics | `pkg/http/otel.go:298-304` |
| HTTP client (recommendations → catalog/copy) | `otelhttp.NewTransport` (auto) | Client spans, `http_client_request_duration` metrics, linked to the parent server span via context propagation | `cmd/main.go:183`, `pkg/http/http.go:442` |
| Database (Bun ORM) | `bunotel.NewQueryHook` (auto) | One span per SQL query, nested under the request span | `pkg/database/database.go:49-51` |
| Business logic | 2 manual `tracer.Start()` calls | `pizza-generation` and `name-generation` spans, nested under `POST /api/pizza` | `pkg/http/http.go:1474`, `pkg/http/http.go:1480` |
| Go runtime | `contrib/instrumentation/runtime` (auto) | GC/goroutine/memory metrics, exported via OTLP metrics | `pkg/http/otel.go:276-278` |
| gRPC | **none** | No spans or metrics — `grpc.NewServer()` has no `otelgrpc` interceptors | `pkg/grpc/grpc.go:46` |
| Application counters/histograms | Prometheus client (not OTel) | `quickpizza_server_*` metrics, exposed on `/metrics` | `pkg/http/http.go` (`pizzaRecommendations`, `numberOfIngredientsPerPizza`, etc.) |
| Profiling | Pyroscope + `otel-profiling-go` | Span-linked CPU/memory profiles | `pkg/http/otel.go:271,287` (`otelpyroscope.NewTracerProvider`) |
| Baggage | `baggagecopy.NewSpanProcessor` (auto) | Copies all baggage members onto every span as attributes | `pkg/http/otel.go:138-144` |

The manual spans exist specifically because nothing else creates a span boundary around that code: it's an in-process loop with random delays/CPU work, not an HTTP/DB/gRPC call that auto-instrumentation could see. If you add a new manual span, add a row here.

### Why traces span multiple services

In the microservices compose stack, `public-api` calls `recommendations`, which calls `catalog` and `copy` over HTTP. Because both client and server sides use the same `otelhttp` propagators (`TraceContext` + `Baggage`, set in `otel.SetTextMapPropagator`), a single trace ID flows across all four services. Querying Tempo for `{name="POST /api/pizza"}` returns one trace with span counts broken down per service (see [Testing](#testing-that-traces-are-exported) below).

## Testing that traces are exported

The fastest way to confirm instrumentation is actually emitting data — not just that the code compiles — is to exercise a real request and check the destination (Tempo for traces, `/metrics` or the OTLP collector for metrics), rather than just running `go build`/`go test`.

### 1. Point the app at an OTLP endpoint

If you're running one of the `compose.grafana-local-stack.*.yaml` stacks, this is already done — check with:

```bash
docker inspect <container> --format '{{range .Config.Env}}{{println .}}{{end}}' | grep OTEL
```

You should see `QUICKPIZZA_OTLP_ENDPOINT=http://alloy:4318` (or similar). If running the binary standalone, set it yourself:

```bash
QUICKPIZZA_OTLP_ENDPOINT=http://localhost:4318 ./bin/quickpizza
```

### 2. Exercise a traced endpoint

`/api/pizza` requires an authenticated user:

```bash
# Register a user
curl -s -X POST http://localhost:3333/api/users -H "Content-Type: application/json" \
  -d '{"username":"otel-test","password":"otel-test-pw"}'

# Log in to get a token
TOKEN=$(curl -s -X POST http://localhost:3333/api/users/token/login -H "Content-Type: application/json" \
  -d '{"username":"otel-test","password":"otel-test-pw"}' | python3 -c "import sys,json; print(json.load(sys.stdin)['token'])")

# Generate a pizza recommendation (this is the endpoint with manual spans)
curl -s -X POST http://localhost:3333/api/pizza -H "Content-Type: application/json" \
  -H "Authorization: Token $TOKEN" \
  -d '{"maxCaloriesPerSlice":1000,"mustBeVegetarian":false,"excludedIngredients":[],"excludedTools":[],"maxNumberOfToppings":5,"minNumberOfToppings":2}'
```

### 3. Confirm the trace landed in Tempo

Using TraceQL search against Tempo's HTTP API (default port `3200` in the local Grafana stack):

```bash
curl -s 'http://localhost:3200/api/search?q=%7Bname%3D%22POST%20%2Fapi%2Fpizza%22%7D&limit=3' | python3 -m json.tool
```

A healthy result includes a `serviceStats` breakdown showing spans from every service in the call chain, e.g.:

```json
"serviceStats": {
  "public-api": {"spanCount": 2},
  "recommendations": {"spanCount": 13},
  "catalog": {"spanCount": 31},
  "copy": {"spanCount": 4}
}
```

If a service is missing from `serviceStats`, or `spanCount` looks too low, that service's `Install()` call, OTLP endpoint config, or propagator setup is worth checking.

You can also fetch a single trace in full (e.g. to inspect resource attributes like `telemetry.sdk.version`, or nested span names like `pizza-generation`):

```bash
curl -s "http://localhost:3200/api/traces/<traceID>"
```

### 4. Check metrics export

Prometheus-scraped metrics (including OTel's `http_server_*`/`http_client_*`, which are dual-exported to Prometheus) are on:

```bash
curl -s http://localhost:3333/metrics | grep http_server_request_duration
```

OTLP metrics are pushed to the collector every 5 seconds (`sdkmetric.WithInterval(5*time.Second)` in `createMetricProvider`) — there's no pull endpoint to check directly; verify via whatever backend the collector forwards to (e.g. a Prometheus remote-write target, or the collector's own debug/logging exporter).
