# TODO: Crash Reporting via MetricKit + OpenTelemetry

## Goal

Implement first-party crash reporting using Apple's MetricKit framework and the
OpenTelemetry Swift SDK's `MetricKitInstrumentation`, sending crash diagnostics
as OTel logs/spans to Grafana. No dependency on Sentry, Crashlytics, etc.

## Background

The `opentelemetry-swift` SDK already includes a `MetricKitInstrumentation`
library that converts MetricKit payloads into OpenTelemetry signals. It lives at:
`Sources/Instrumentation/MetricKit/` in the
[opentelemetry-swift](https://github.com/open-telemetry/opentelemetry-swift) repo.

The instrumentation captures two categories of data:

### Metrics (MXMetricPayload) → OTel Spans
Aggregated 24-hour performance data reported as a single span with attributes:
- CPU time, GPU time, memory usage, disk I/O
- App launch times, hang durations, scroll hitch ratios
- Network transfer (WiFi/cellular upload/download)
- App exit counts (foreground/background, normal/abnormal)

### Diagnostics (MXDiagnosticPayload) → OTel Logs
Individual events (crashes, hangs, CPU/disk exceptions) reported as log records:
- **Crashes** — Mach exception type, signal, ObjC exception info (iOS 17+),
  termination reason, full call stack tree
- **Hangs** — Duration + call stack tree
- **CPU exceptions** — Total CPU time + sampled time
- **Disk write exceptions** — Total writes caused
- **App launch diagnostics** — Launch duration (iOS 16+)

Exception attributes follow OTel semantic conventions:
- `exception.type` — Derived from ObjC name > Mach exception > POSIX signal
- `exception.message` — Derived from ObjC message > Mach description > signal description
- `exception.stacktrace` — JSON call stack tree from MetricKit

## Implementation Steps

### 1. Add the MetricKitInstrumentation dependency
The `MetricKitInstrumentation` library is a product of `opentelemetry-swift`.
Add it to the Xcode project's SPM dependencies (it's in the same package you
already depend on).

### 2. Register the instrumentation at app startup
```swift
import MetricKit

// In AppDelegate or app init — store in a static/app-level var
// because MXMetricManager only holds a weak reference.
if #available(iOS 13.0, *) {
    let metricKit = MetricKitInstrumentation()
    MXMetricManager.shared.add(metricKit)
    // e.g. AppDelegate.metricKitInstrumentation = metricKit
}
```

### 3. (Optional) Custom configuration
```swift
let config = MetricKitConfiguration(
    useAppleStacktraceFormat: false, // use OTel format
    tracer: customTracer
)
let metricKit = MetricKitInstrumentation(configuration: config)
```

### 4. Symbolication pipeline
MetricKit call stack trees contain unsymbolicated memory addresses. To make
stack traces human-readable:

- **Upload dSYMs** — After each release build, upload dSYM files to a storage
  location (e.g. GCS bucket, S3) keyed by build version
- **Server-side symbolication** — Build or use a collector processor that
  matches addresses against dSYMs. Options:
  - OTel Collector processor (custom or community)
  - Post-processing in Grafana/Tempo
  - Batch job that symbolicates stored traces
- **Apple's `atos` tool** — Can symbolicate addresses given dSYM + load address:
  `atos -arch arm64 -o MyApp.app.dSYM/Contents/Resources/DWARF/MyApp -l 0x1000 0x1234`

### 5. Verify data flow
- Build a debug version and trigger a test crash
- MetricKit delivers payloads ~24h later (or use Xcode's
  `Debug > Simulate MetricKit Payloads` for testing)
- Confirm spans/logs appear in Grafana with expected attributes

## Notes

- MetricKit data is delivered approximately once per day with 24h aggregated data
- Diagnostic payloads are available from iOS 14+
- ObjC exception details (name, message, className) require iOS 17+
- App launch diagnostics require iOS 16+ and are not available on macOS
- The instrumentation uses scope name `"MetricKit"` with version `"0.0.1"`
- Our `Span.recordException()` is for application-level caught errors (network
  failures, auth errors, etc.) — it does NOT capture stack traces because Swift
  errors don't carry throw-site stack traces. MetricKit is the right tool for
  actual crash stack traces.
