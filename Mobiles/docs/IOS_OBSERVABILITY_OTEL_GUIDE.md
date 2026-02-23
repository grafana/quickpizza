# iOS OpenTelemetry Instrumentation Guide (QuickPizza)

This guide explains how the QuickPizza iOS app is instrumented today with OpenTelemetry Swift, what data it emits, and how to apply the same approach in your own app.

Audience:
- Demo teams who need to explain the telemetry model to customers
- iOS engineers who want to copy this setup

## 1. High-level architecture

Telemetry is initialized once at app startup:

- `Bootstrap.initialize()` resolves and initializes `OTelService`
- `OTelService` registers global OTel providers and instrumentations
- Feature repositories use injected `Tracing` and `Logging` abstractions

Key files:
- `Mobiles/ios/QuickPizzaIos/Bootstrap.swift`
- `Mobiles/ios/QuickPizzaIos/Core/O11y/OTelService.swift`
- `Mobiles/ios/QuickPizzaIos/Core/O11y/Tracer.swift`
- `Mobiles/ios/QuickPizzaIos/Core/O11y/Logger.swift`

## 2. Which telemetry signals are emitted

QuickPizza iOS emits:

1. Traces
- Manual spans around key business operations (login, recommendation, rating)
- Auto HTTP client spans via `URLSessionInstrumentation`
- MetricKit payload spans (pre-aggregated Apple performance data)

2. Logs
- Application logs (`debug`, `info`, `warning`, `error`)
- Exception logs via custom `logger.exception(...)`
- Session lifecycle logs (`session.start`, `session.end`) from Sessions instrumentation
- MetricKit diagnostics logs (including crashes/hangs)

3. Metrics
- No custom OTel Metrics API instrumentation yet
- MetricKit performance data is represented as spans (SDK design)

## 3. What data is collected

### 3.1 Resource attributes (all telemetry)

Configured in `OTelService.buildResource(...)`:
- `service.name` (default `quickpizza-ios`)
- `service.namespace` (`quickpizza`)
- `service.version` (app version)
- `service.build` (bundle build number)
- `deployment.environment` (default `production`)

### 3.2 Sessions

Configured in `setupSessions()`:
- Session timeout: 15 minutes of inactivity
- Span enrichment: `SessionSpanProcessor()`
- Log enrichment: `SessionLogRecordProcessor(...)`
- Session events: `SessionEventInstrumentation.install()`

Attributes added by session processors include:
- `session.id`
- `session.previous_id` (when available)

### 3.3 Manual traces

Examples:
- `auth.login` span
- `pizza.get_recommendation` span
- `pizza.rate` span

Typical span attributes:
- `http.status_code`
- domain attributes like `pizza.id`, `pizza.name`, `pizza.stars`, `auth.result`

### 3.4 Auto HTTP spans

`URLSessionInstrumentation` is enabled globally.

The OTLP host is excluded from auto-instrumentation to avoid exporter self-tracing loops.

### 3.5 Application logs and exception logs

App logger is a composite:
- OSLog (Xcode/device console)
- OpenTelemetry logger provider

`logger.error(...)` emits error logs and sets OTel semantic attributes when an `Error` exists:
- `error.type`
- `error.message`

`logger.exception(...)` emits an exception-style log with:
- `eventName = "exception"`
- `exception.type`
- `exception.message`
- `exception.stacktrace` (current thread call stack)
- `error.type`

### 3.6 Crash and hang diagnostics (MetricKit)

`MetricKitInstrumentation` is registered in `setupMetricKitInstrumentation()` and retained on the service (required because `MXMetricManager` keeps weak references).

It sends:
- Metric payloads as spans (windowed/aggregated)
- Diagnostic entries as logs:
  - `metrickit.diagnostic.crash`
  - `metrickit.diagnostic.hang`
  - `metrickit.diagnostic.cpu_exception`
  - `metrickit.diagnostic.disk_write_exception`
  - `metrickit.diagnostic.app_launch` (platform/version dependent)

Crash/hang log attributes include OTel exception semantic fields such as:
- `exception.type`
- `exception.message`
- `exception.stacktrace`

Important delivery model:
- MetricKit is delayed and batched by Apple (not realtime crash streaming)
- Diagnostics are generally delivered in later payloads, often tied to 24h reporting windows

## 4. Export model (where telemetry goes)

Configured via `Config.xcconfig` values that are generated into `BuildConfig` at build time.

Inputs:
- `OTLP_ENDPOINT`
- `OTLP_AUTH_HEADER`

Behavior:
- If `OTLP_ENDPOINT` is set: traces -> `/v1/traces`, logs -> `/v1/logs` (OTLP HTTP)
- If `OTLP_ENDPOINT` is empty: no OTLP exporters are attached
  - traces still print in debug via `OSLogSpanExporter`
  - logs are still available in OSLog via `ConsoleLogger`

Related files:
- `Mobiles/ios/Config.xcconfig.example`
- `Mobiles/ios/Scripts/generate-config.sh`
- `Mobiles/ios/QuickPizzaIos/Core/Config/ConfigService.swift`

## 5. Demo workflow (customer-facing)

For quick demos, use the in-app Debug tab:
- `Send logger.exception`
- `Trigger test crash`

Files:
- `Mobiles/ios/QuickPizzaIos/Features/Debug/Presentation/DebugView.swift`
- `Mobiles/ios/QuickPizzaIos/Features/Debug/Presentation/DebugViewModel.swift`

Expected outcome:
1. `logger.exception` appears quickly as an error/exception log in backend.
2. Crash diagnostics via MetricKit arrive later (delayed, batched).

## 6. How to apply this in your own iOS app

Use this checklist:

1. Add OpenTelemetry Swift packages
- Core SDK + OTLP HTTP exporters
- `URLSessionInstrumentation`
- `Sessions`
- `MetricKitInstrumentation`

2. Initialize once at app startup
- Register tracer and logger providers
- Set resource attributes (`service.*`, environment)

3. Enable session processors
- `SessionSpanProcessor`
- `SessionLogRecordProcessor`
- `SessionEventInstrumentation.install()`

4. Enable URLSession auto tracing
- Add exclusion for your OTLP host

5. Add structured app logging facade
- Include `error` and optional `exception` API
- Map to OTel semantic attributes (`error.*`, `exception.*`)

6. Register MetricKit instrumentation
- Keep a strong reference to instrumentation instance

7. Add test hooks
- Non-prod debug screen/action for exception + intentional crash

8. Validate end-to-end
- Verify traces and logs in backend
- Verify delayed MetricKit crash delivery behavior

## 7. Known limitations and nuances

- MetricKit crash reporting is delayed by Apple and delivered in payload windows.
- `session.previous_id` is not a guaranteed 1:1 crash-to-session mapping in all delayed-delivery scenarios.
- `logger.exception(...)` and MetricKit crash logs are both logs, but represent different sources:
  - `logger.exception`: app-triggered exception event now
  - MetricKit crash log: OS-reported diagnostic event later

## 8. Current QuickPizza iOS instrumentation inventory

Implemented now:
- OTel traces (manual + URLSession auto)
- OTel logs (app logs + exception logs)
- Session enrichment on spans/logs
- MetricKit crash/hang/diagnostic ingestion
- Debug tab for exception and crash testing

Not yet implemented:
- Custom OTel Metrics API instrumentation
- Crash dedup strategy in app code
- Explicit crash-to-session linkage strategy beyond default session attributes

---

If you are presenting this to customers, the main talking point is:
"We combine immediate in-app observability (traces/logs) with delayed OS-level diagnostics (MetricKit), all through standard OTLP signals."
