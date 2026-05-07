# Mobile Observability Overview

This document explains what each QuickPizza mobile demo app does, how it is
instrumented, what telemetry it emits, and where that telemetry lands in
Grafana Cloud.

It is intended for two audiences:

- **Demo presenters / SEs** — start with [§ At a glance](#at-a-glance) and
  [§ Where the data lives](#where-the-data-lives).
- **Engineers onboarding to the demo** — read on through
  [§ Per-platform telemetry inventory](#per-platform-telemetry-inventory) and
  [§ iOS vs Android native: what differs](#ios-vs-android-native-what-differs).

> **Demo stack:** an internal Grafana Cloud stack used by the QuickPizza demo
> team. The concrete telemetry shown below was inventoried from that stack via
> `gcx`. The shape of the data is portable to any Grafana Cloud stack — the
> stack-specific URLs and slugs in this doc are placeholders; substitute your
> own when running these apps yourself. See
> [§ How this was verified](#how-this-was-verified) for the exact queries.

---

## Table of contents

- [At a glance](#at-a-glance)
- [What every QuickPizza mobile app does](#what-every-quickpizza-mobile-app-does)
- [Where the data lives](#where-the-data-lives)
- [Per-platform telemetry inventory](#per-platform-telemetry-inventory)
  - [Flutter (Faro)](#flutter-faro)
  - [React Native (Faro)](#react-native-faro)
  - [iOS native (OpenTelemetry Swift)](#ios-native-opentelemetry-swift)
  - [Android native (OpenTelemetry Android)](#android-native-opentelemetry-android)
- [iOS vs Android native: what differs](#ios-vs-android-native-what-differs)
- [Faro vs OpenTelemetry: side-by-side](#faro-vs-opentelemetry-side-by-side)
- [The shared Debug screen](#the-shared-debug-screen)
- [Known issues / open questions](#known-issues--open-questions)
- [How this was verified](#how-this-was-verified)

---

## At a glance

| Platform | App location | SDK | Service / app name in telemetry | Backend |
| --- | --- | --- | --- | --- |
| Flutter (Android + iOS) | `Mobiles/flutter/` | `faro` Dart SDK | `QuickPizza_Flutter` (app_id `69`) | Faro collector → Grafana Cloud Frontend Observability |
| React Native (Android + iOS) | `Mobiles/react-native/` | `@grafana/faro-react-native` | `QuickPizza_ReactNative` (app_id `123`) | Faro collector → Grafana Cloud Frontend Observability |
| iOS native (SwiftUI) | `Mobiles/ios/` | `opentelemetry-swift` | `quickpizza-ios` | OTLP/HTTP → Grafana Cloud Tempo + Loki |
| Android native (Compose) | `Mobiles/android/` | `opentelemetry-android` (RUM agent) | `quickpizza-android` | OTLP/HTTP → Grafana Cloud Tempo + Loki |

All four apps talk to the same QuickPizza backend (`/api/pizza`,
`/api/ratings`, `/api/users/token/login`, …) and implement the same core
flows: get a pizza recommendation, rate it, log in, view your profile, and a
shared in-app **Debug** tab for triggering errors/crashes (see
[§ The shared Debug screen](#the-shared-debug-screen)).

---

## What every QuickPizza mobile app does

The user-facing feature set is **the same across all four apps** by design,
so that the four implementations can be compared apples-to-apples for
observability demos. Required screens and workflows are documented in
[`Mobiles/FEATURES.md`](../FEATURES.md).

Common feature set:

- **Home** — get a pizza recommendation; customize calories/toppings/tools.
- **Login** — token auth (`default` / `12345678`).
- **Profile** — list/clear ratings, sign out.
- **About** — app metadata, SDK references.
- **Debug** — shared cross-platform screen for runtime config overrides,
  backend error/latency injection, client-side fault simulation, and
  triggering test logs/exceptions/native crashes.

---

## Where the data lives

| App | Visualisation |
| --- | --- |
| Flutter | Frontend Observability plugin → `/a/grafana-kowalski-app/apps/<faro-app-id>` on your Grafana Cloud stack |
| React Native | Frontend Observability plugin → `/a/grafana-kowalski-app/apps/<faro-app-id>` on your Grafana Cloud stack |
| iOS native | "Android & iOS OTel RUM" dashboard (and an iOS-specific dashboard) on your Grafana Cloud stack |
| Android native | "Android & iOS OTel RUM" dashboard on your Grafana Cloud stack |

Underlying datasources on whichever Grafana Cloud stack you target:

- Faro signals → the stack's Loki datasource (`grafanacloud-<stack>-logs`).
  Faro stores all four signal kinds (`event`, `log`, `measurement`,
  `exception`) as Loki streams with `app_id` / `app_name` labels.
- OTel signals → the stack's Tempo datasource
  (`grafanacloud-<stack>-traces`) for spans and the stack's Loki datasource
  for log records, both labeled with `service_name` / `service_namespace`.

The Frontend Observability plugin queries Loki for Faro-shaped data; the
"Android & iOS OTel RUM" dashboard queries Tempo + Loki for OTel-shaped data.

---

## Per-platform telemetry inventory

The tables below show what each app actually emitted into our internal demo
stack over a recent window, grouped by signal kind. Anything labeled
**(auto)** comes from the SDK or an SDK-bundled instrumentation; **(manual)**
is code we wrote in `core/o11y/` or in the feature repositories.

### Flutter (Faro)

- **SDK:** `faro-mobile-flutter` 0.14.0
- **Init:** `Mobiles/flutter/lib/bootstrap.dart` → `Faro` from
  `package:faro`
- **Faro app:** registry name `QuickPizza_Flutter`, id `69`. The SDK is
  configured in `Mobiles/flutter/lib/bootstrap.dart` to send
  `app_name=QuickPizza_Flutter`, matching the React Native app
  (`QuickPizza_ReactNative`).

| Signal kind | Examples | Source |
| --- | --- | --- |
| `event` | `faro.tracing.fetch` (HTTP auto), `user_interaction`, `view_changed`, `app_lifecycle_changed`, `session_start`, `faro.user.action`, `pizza_requested`, `pizza_received`, `pizza_rated`, `login_screen_opened`, `user_logged_out` | mostly auto; `pizza_*` and `login_*` are manual via `core/o11y/events/o11y_events.dart` |
| `log` | severity `debug` / `warn` / `error` | manual via `core/o11y/loggers/o11y_logger.dart` (`MultiO11yLogger` → `ConsoleO11yLogger` + `FaroO11yLogger`) |
| `exception` | type `API`, `UI`, `flutter_error` | manual via `core/o11y/errors/o11y_errors.dart` + Faro's global Flutter error handler installed by `faro.runApp` |
| `measurement` | `app_memory`, `app_cpu_usage`, `app_refresh_rate`, `app_frames_rate`, `app_frozen_frame`, `app_startup` | auto, from Faro mobile metrics instrumentation |

Resource attributes on every signal: `app_name`, `app_version`,
`app_environment=production`, `sdk_name`, `sdk_version`, `user_id`,
`user_username`, `session_id`, plus a rich `session_attr_*` block (Dart
version, device brand/manufacturer/model/id, `device_is_physical`, OS,
detailed OS string).

Native crashes on Flutter Android arrive via a custom `MethodChannel`-based
`NativeCrashService` (see `Mobiles/flutter/lib/features/debug/domain/`),
which exercises Faro's `crash` exception path on the next launch.

### React Native (Faro)

- **SDK:** `faro-react-native` 2.3.1, integration
  `@grafana/faro-react-native:1.0.0` (alpha — see RN README)
- **Init:** `Mobiles/react-native/src/bootstrap.ts` →
  `core/o11y/faroSdk.ts`
- **Faro app:** registry name `QuickPizza_ReactNative`, id `123`

| Signal kind | Examples | Source |
| --- | --- | --- |
| `event` | `faro.tracing.fetch` + `faro.tracing.xml-http-request` (HTTP auto via dual fetch+XHR interception), `view_changed`, `faro.user.action`, `app_lifecycle_changed`, `session_start`, `faro_initialized`, `pizza_requested` / `pizza_received` / `pizza_rated`, `login_screen_opened`, `user_logged_out`, `debug_custom_event` | mostly auto; pizza/login/debug events are manual via `src/core/o11y/o11yEvents.ts` |
| `log` | severity `debug` / `info` / `warn` / `error` | manual via `src/core/o11y/o11yLogs.ts` |
| `exception` | type `crash` (native, e.g. `CRASH_NATIVE: Application crash (Native), status: 11`), `Error`, `PizzaRecommendationError`, `HandledDebugException` | crash auto via Faro CrashKit; others manual via `src/core/o11y/o11yErrors.ts` |
| `measurement` | `app_memory`, `app_cpu_usage`, `app_frames_rate`, `app_frozen_frame`, `app_startup`, plus app-specific `pizza.recommendation`, `pizza.rating` | auto, plus custom via `src/core/o11y/o11yMetrics.ts` |

Resource attributes are similar to Flutter but **richer**: includes
`device_battery_level`, `device_is_charging`, `device_carrier`,
`device_memory_total`, `device_memory_used`, `device_type`, and
`react_native_version`. RN sets `app_environment=development` (Flutter
sets `production`).

Custom `pizza.recommendation` / `pizza.rating` measurements are unique to
the RN app — Flutter doesn't currently emit business measurements.

### iOS native (OpenTelemetry Swift)

- **SDK:** `opentelemetry-swift` 2.3.0 (`telemetry_sdk_language=swift`,
  `telemetry_sdk_name=opentelemetry`)
- **Init:** `Mobiles/ios/QuickPizzaIos/Bootstrap.swift` →
  `Core/O11y/OTelService.swift`
- **OTel service.name:** `quickpizza-ios`,
  service.namespace `quickpizza`

| Signal | Examples | Source |
| --- | --- | --- |
| Spans (Tempo) | `HTTP GET` (auto, `URLSessionInstrumentation`), `pizza.get_recommendation` / `auth.login` / `pizza.rate` (manual), `MXMetricPayload` (auto, MetricKit pre-aggregated 24h payloads) | manual via `Core/O11y/Tracer.swift`; HTTP auto via `URLSessionInstrumentation`; MetricKit auto via `MetricKitInstrumentation` |
| Logs (Loki) | severity `INFO` / `DEBUG` / `WARN` / `ERROR`; `event_name=app.screen.view` (manual screen-view tracking), `session.start` / `session.end` (auto from Sessions instrumentation), `event_name=exception` for `logger.exception(...)`, MetricKit `metrickit.diagnostic.*` for crashes/hangs/CPU/disk-write exceptions | manual app logger + auto SDK |
| Metrics | _none yet_ — there is no `MeterProvider` configured. MetricKit performance data is delivered as spans, not metrics. | — |

Resource attributes carry: `service.name`, `service.namespace`,
`service.version`, `service.build`, `deployment.environment`, `os.name`,
`os.version`, `os.description`, `device.id`, `device.model.identifier`
(e.g. `iPhone16,1`), `session.id`, `session.previous_id`,
`telemetry.sdk.{language, name, version}`, `scope.name`.

**iOS does not auto-emit** `screen.view`, lifecycle spans (`AppStart` /
`Paused` / `Stopped`), `app.jank`, or `device.crash` events. The iOS app
**does** emit `app.screen.view` events manually via a `.trackScreenView()`
view modifier.

For deeper iOS detail see
[`IOS_OBSERVABILITY_OTEL_GUIDE.md`](./IOS_OBSERVABILITY_OTEL_GUIDE.md).

### Android native (OpenTelemetry Android)

- **SDK:** `opentelemetry-android` 1.2.0-alpha (`telemetry_sdk_language=java`)
- **Init:** `Mobiles/android/app/src/main/java/com/grafana/quickpizza/core/o11y/OTelService.kt`
  → `OpenTelemetryRumInitializer.initialize(...)`
- **OTel service.name:** `quickpizza-android`, service.namespace `quickpizza`

| Signal | Examples | Source |
| --- | --- | --- |
| Spans (Tempo) | `GET` (auto, OkHttp telemetry), `AppStart` / `Paused` / `Stopped` (auto, lifecycle instrumentation), `pizza.get_recommendation` / `auth.login` / `pizza.rate` (manual) | manual via `core/o11y/AppTracer.kt`; rest auto from RUM agent |
| Logs (Loki) | `event_name=screen.view` (auto), `event_name=app.jank` (auto, slow-rendering instrumentation), `session.start` (auto), `rum.sdk.init.{started, span.exporter, net.provider}` (auto SDK self-telemetry), `event_name=exception` (manual `logger.exception`), `event_name=device.crash` (auto, persisted by `CrashReporter` and delivered next launch), `event_name=device.anr` (auto ANR detection), `event_name=debug.test_event` (manual from Debug screen) | mostly auto; `exception` and `debug.*` are manual |
| Metrics | _none custom_ — but the RUM agent computes things like jank counts and exposes them as events rather than metrics. | — |

Resource attributes are **the richest of any platform**: `service.*`,
`deployment.environment`, `os.name`, `os.version`, `os.description`,
`android.os.api_level`, `device.manufacturer`, `device.model.identifier`,
`device.model.name`, `network.connection.type` (e.g. `wifi`),
`app.installation.id`, `screen.name` (current Activity), `nav.destination`
+ `nav.previous_destination` + `nav.kind` (Compose navigation), `session.id`,
`telemetry.sdk.{language, name, version}`,
`scope.name=com.grafana.quickpizza`.

> **Last verified in cloud:** ~2026-04-24 (the Android demo app hadn't sent
> data to the demo stack in the ~12 days before this doc was written; the
> emit list above reflects what was last seen plus what the code in
> `Mobiles/android/` registers).

---

## iOS vs Android native: what differs

Both export OTel/HTTP to the same Grafana Cloud stack, but the SDKs do
materially different amounts of work for you out of the box.

| Concern | iOS (`opentelemetry-swift`) | Android (`opentelemetry-android`) |
| --- | --- | --- |
| Auto HTTP spans | Yes — `URLSessionInstrumentation` | Yes — OkHttp `Call.Factory` wrapper |
| Auto lifecycle spans | **No** | Yes — `AppStart`, `Paused`, `Stopped` |
| Auto screen view events | **No** (we emit `app.screen.view` manually via a SwiftUI view modifier) | Yes — `event_name=screen.view` |
| Auto crash capture | Via Apple **MetricKit** — delayed (hours / next 24h window) and batched | Via OTel-Android `CrashReporter` — real‑time on next app launch |
| Auto ANR / hang | Via MetricKit (delayed) | Yes — `event_name=device.anr` runtime |
| Auto slow-frame / jank | **No** (MetricKit hitch metrics arrive as `MXMetricPayload` spans) | Yes — `event_name=app.jank` |
| Auto session lifecycle | Yes — `Sessions` library (`session.start` / `session.end` log records, `session.id` + `session.previous_id` on every signal) | Yes — emits `session.start`; `session.id` on every signal |
| Network class attribute | _Not exposed_ | Yes — `network.connection.type` (e.g. `wifi`) |
| Compose / SwiftUI nav attrs | _None_ | Yes — `nav.destination` / `nav.previous_destination` / `nav.kind` |
| Device hardware attrs | `device.id`, `device.model.identifier` | `device.manufacturer`, `device.model.identifier`, `device.model.name`, `android.os.api_level`, `app.installation.id` |
| Performance / Apple-specific | `MXMetricPayload` spans (CPU, memory, hangs, hitch ratios — daily) | `app.jank` events, `rum.sdk.init.*` self-telemetry |
| Custom OTel Metrics API | Not configured | Not configured |

**Headline:** Android's RUM agent gives you an order of magnitude more
auto-instrumentation than the iOS Swift SDK does today. On iOS we
compensate for that by (a) wiring `MetricKitInstrumentation` for OS-level
diagnostics, and (b) manually emitting `app.screen.view` and business
events.

---

## Faro vs OpenTelemetry: side-by-side

| | Faro (Flutter, RN) | OpenTelemetry (iOS, Android) |
| --- | --- | --- |
| Wire format | Faro JSON → Faro collector | OTLP/HTTP → Grafana Alloy / Grafana Cloud |
| Signal model | Four kinds: `event`, `log`, `measurement`, `exception`. All flattened into Loki. | Two kinds we use today: spans (Tempo) + log records (Loki). |
| Auto HTTP | Faro fetch/XHR instrumentation emits `event_name=faro.tracing.*` events that double as spans (with `traceID`/`spanID`) | Native HTTP client wrappers emit OTel spans |
| Auto user actions | `event_name=faro.user.action` (Flutter + RN) | _None_ |
| Auto perf metrics | `app_memory`, `app_cpu_usage`, `app_frames_rate`, `app_frozen_frame`, `app_startup` (both) | _None on iOS_; `app.jank` events on Android |
| Crashes | Native crash → `kind=exception, type=crash` (FaroCrashKit) | iOS: MetricKit (delayed); Android: `device.crash` event (next launch) |
| Where to query | Frontend Observability plugin (Loki under the hood) | Tempo + Loki via Explore + custom dashboards |
| Where to view | Frontend Observability plugin (per-app drilldown UI) | "Android & iOS OTel RUM" dashboard |
| User context | `user_id` / `user_username` (Faro auto when set via SDK) | Not yet attached on every signal — `enduser.id` is the OTel attribute to use; tracked in [#48](https://github.com/grafana/mobile-o11y-demo/issues/48) / [`OTEL_MOBILE_MATURITY.md` § M-001](./OTEL_MOBILE_MATURITY.md#m-001--no-first-class-user-context-enduserid-on-mobile-sdks) |

---

## The shared Debug screen

All four apps now have a feature-aligned **Debug** tab that lets demo
presenters trigger telemetry on demand. The screen has the same five
sections everywhere:

1. **Config entry card** — opens a sub-screen for runtime overrides of
   `BASE_URL`, OTLP endpoint / Faro collector URL, and credentials.
   Overrides persist to local storage and apply on next launch (a
   "Restart required" banner shows when the active config differs from
   the saved one).
2. **Error simulation** — toggles that propagate to the QuickPizza
   backend via headers (`x-error-record-recommendation`,
   `x-delay-record-recommendation`, `x-error-get-ingredients`,
   `x-delay-get-ingredients`) plus client-side faults
   (`useV2PizzaSchema`, `skipAuthDepInTools`).
3. **Quick signals** — buttons to send a debug log, an error log, and a
   custom event end-to-end through the SDK.
4. **Handled exception** — throws inside a `try/catch` and reports it via
   the appropriate API (`o11yErrors.reportError` for Faro,
   `logger.exception(...)` for OTel).
5. **Native crash** — terminates the app via a real native crash so we
   can exercise the crash-reporting path.

Per-platform extras:

- **Android only:** an **OTel SDK section** with a `Disable disk
  buffering` toggle (turn off for ~1–6s telemetry latency at the cost
  of offline resilience, vs the default ~30–45s buffered window) and an
  **ANR card** that blocks the main thread for 6 s.
- **iOS only:** the **Crash Reporting** card explicitly notes that
  MetricKit crash diagnostics are delivered by Apple later and may not
  show up immediately in Grafana Cloud.

Code:

- Flutter — `Mobiles/flutter/lib/features/debug/presentation/debug_screen.dart`
- React Native — `Mobiles/react-native/src/features/debug/presentation/DebugScreen.tsx`
- iOS — `Mobiles/ios/QuickPizzaIos/Features/Debug/Presentation/DebugView.swift`
- Android — `Mobiles/android/app/src/main/java/com/grafana/quickpizza/features/debug/DebugScreen.kt`

---

## Known issues / open questions

**SDK-level gaps** (missing capabilities, awkward APIs — candidates for
upstream contribution) are tracked separately in
[`OTEL_MOBILE_MATURITY.md`](./OTEL_MOBILE_MATURITY.md). Currently logged
there:

- `M-001` — No first-class user context (`enduser.id`) on the mobile OTel
  SDKs (tracked in [#48](https://github.com/grafana/mobile-o11y-demo/issues/48)).
- `M-002` — No first-class OTel Metrics support on mobile.
- `M-003` — Android RUM agent processor extensibility (needs verification).
- `M-004` — Screen / view transitions not captured as spans (iOS has no
  screen detection at all; Android emits `screen.view` log events but not
  spans).

---

## How this was verified

The platform tables above were built by running queries against our internal
demo stack via `gcx`. The same queries work against any Grafana Cloud stack
that the apps are emitting to — substitute your own context name and Faro app
IDs.

```bash
gcx config use-context <your-stack-context>

# Faro app discovery
gcx frontend apps list -o json \
  | tail -n +2 | jq -r '.[] | select(.spec.name | test("QuickPizza"; "i")) | "\(.spec.id)\t\(.spec.name)"'

# Faro signal kinds, last 7 days, for app_id=69 (Flutter) / 123 (RN)
gcx logs query -d grafanacloud-logs \
  'sum by (kind) (count_over_time({app_id="69"}[24h]))' \
  --since 168h --step 24h -o json

# Faro top events
gcx logs query -d grafanacloud-logs \
  'topk(30, sum by (event_name) (count_over_time({app_id="69", kind="event"} | logfmt event_name [24h])))' \
  --since 168h --step 24h -o json

# OTel spans for native apps
gcx traces query -d grafanacloud-traces \
  '{resource.service.name="quickpizza-ios"}' --since 168h --limit 200 -o json
gcx traces query -d grafanacloud-traces \
  '{resource.service.name="quickpizza-android"}' --since 720h --limit 200 -o json

# OTel log event_names (Android RUM agent emits a lot of these)
gcx logs query -d grafanacloud-logs \
  'sum by (event_name) (count_over_time({service_name="quickpizza-android"}[24h]))' \
  --since 720h --step 24h -o json
```

For deeper investigations against any of these apps, the `debug-faro-app`
Claude skill (Faro side) and `gcx skills install debug-with-grafana` (general
OTel side) both apply.
