# QuickPizza Android Demo App

A native Kotlin / Jetpack Compose app that demonstrates mobile observability
using the [`opentelemetry-android`](https://github.com/open-telemetry/opentelemetry-android)
RUM agent. It connects to the QuickPizza backend and exports traces and
logs over OTLP/HTTP to Grafana Cloud.

For setup details (Android Studio, SDK, emulator, physical devices) see
[`../docs/ANDROID_NATIVE_SETUP.md`](../docs/ANDROID_NATIVE_SETUP.md).

For the cross-platform observability overview (Faro vs OTel, what each
platform emits, dashboards) see
[`../docs/MOBILE_OBSERVABILITY_OVERVIEW.md`](../docs/MOBILE_OBSERVABILITY_OVERVIEW.md).

> **Not the same as the Flutter Android app.** The Flutter implementation
> lives at [`../flutter/`](../flutter/). This directory is the **native**
> Kotlin/Compose app.

---

## Quickstart

```bash
# 1. Configure
cp app/src/main/res/raw/config.json.example \
   app/src/main/res/raw/config.json
# edit OTLP_ENDPOINT, OTLP_INSTANCE_ID, OTLP_API_KEY, BASE_URL

# 2. Start the QuickPizza backend
docker run --rm -d --name quickpizza -p 3333:3333 \
  ghcr.io/grafana/quickpizza-local:latest

# 3. Build and install on a running emulator
cd Mobiles/android
./gradlew installDebug
adb shell am start -n com.grafana.quickpizza/.MainActivity
```

Or open the project in Android Studio (`File → Open → Mobiles/android/`)
and hit **Run ▶**.

Runtime overrides for backend URL, OTLP endpoint, and credentials can be
set from the in-app **Debug → Config** screen without rebuilding. They
persist to `SharedPreferences` and apply on the next launch.

---

## Features

The user-facing screens (Home, Login, Profile, About, Debug) are aligned
with the other QuickPizza mobile apps. See
[`../FEATURES.md`](../FEATURES.md) for the shared feature spec.

The **Debug** tab exposes:

- Runtime config overrides (backend URL, OTLP endpoint, instance ID, API key).
- Backend error/latency injection toggles
  (`x-error-record-recommendation`, `x-delay-record-recommendation`,
  `x-error-get-ingredients`, `x-delay-get-ingredients`).
- Client-side fault simulation (`useV2PizzaSchema`,
  `skipAuthDepInTools`).
- An **OTel SDK section** with a `Disable disk buffering` toggle —
  default-on disk buffering means ~30–45 s end-to-end latency at the
  cost of offline resilience; turning it off gives ~1–6 s latency for
  live demos at the cost of dropping signals if the network is down.
- **Quick signals** — buttons to send a debug log, an error log, and a
  custom event (`debug.test_event`).
- **Handled exception** — emits an OTel exception log via
  `logger.exception(...)`.
- **ANR card** — blocks the main thread for 6 s. Android's 5 s ANR
  threshold trips and `event_name=device.anr` is captured by the OTel
  agent.
- **Crash card** — `RuntimeException` and simulated `NullPointerException`
  variants. The OTel-Android `CrashReporter` persists the crash to disk
  and the exporter delivers it on the next app launch.

---

## Observability

The app uses [`opentelemetry-android`](https://github.com/open-telemetry/opentelemetry-android)
1.2.0-alpha and exports via OTLP/HTTP. Init lives in
`app/src/main/java/com/grafana/quickpizza/core/o11y/OTelService.kt`.

| Signal | Examples |
| --- | --- |
| **Spans** | `GET` (auto OkHttp), `AppStart` / `Paused` / `Stopped` (auto lifecycle), `pizza.get_recommendation` / `auth.login` / `pizza.rate` (manual) |
| **Logs** | `screen.view` (auto), `app.jank` (auto, slow rendering), `session.start` (auto), `rum.sdk.init.*` (auto SDK self-telemetry), `exception` (manual `logger.exception`), `device.crash` (auto, next launch), `device.anr` (auto, runtime), `debug.test_event` (manual) |

Resource attributes:

```
service.name             = quickpizza-android
service.namespace        = quickpizza
service.version          = <versionName>
deployment.environment   = production
android.os.api_level     = 30/34/...
device.manufacturer      = Google / ...
device.model.identifier  = sdk_gphone_arm64 / ...
network.connection.type  = wifi / cellular / ...
app.installation.id      = <stable per install>
session.id               = <15-min inactivity timeout>
telemetry.sdk.language   = java
telemetry.sdk.version    = 1.2.0-alpha
nav.destination          = current Compose route
```

`OTelService` registers `OpenTelemetryRumInitializer` which wires up:

- Auto OkHttp tracing via the `Call.Factory` wrapper.
- Lifecycle / `AppStart` / activity-state spans.
- Slow-rendering / jank detection (`event_name=app.jank`).
- Crash reporting (`CrashReporter`) — persists unhandled exceptions to
  disk and emits `event_name=device.crash` on next launch.
- ANR detection — emits `event_name=device.anr`.
- Sessions — 15-minute inactivity timeout, `session.id` stamped on
  every signal.
- Disk buffering of OTLP exports for offline resilience (toggle off via
  the Debug screen).

Where to view the data on the demo stack:

- **Dashboard:** "Android & iOS OTel RUM" on your Grafana Cloud stack
- **Explore Tempo:** filter by `resource.service.name="quickpizza-android"`
- **Explore Loki:** filter by `service_name="quickpizza-android"`

---

## Configuration reference

`app/src/main/res/raw/config.json` (gitignored — copy from the `.example`):

```json
{
  "OTLP_ENDPOINT": "https://otlp-gateway-prod-eu-west-0.grafana.net/otlp",
  "OTLP_INSTANCE_ID": "1234567",
  "OTLP_API_KEY": "glc_xxxxxxxxxxxx",
  "BASE_URL": ""
}
```

| Field | Description |
| --- | --- |
| `OTLP_ENDPOINT` | OTLP/HTTP base URL (without `/v1/traces`). Empty disables export. |
| `OTLP_INSTANCE_ID` | Numeric Grafana Cloud OTLP gateway instance ID. |
| `OTLP_API_KEY` | Grafana Cloud access token (combined with the instance ID into `Authorization: Basic`). |
| `BASE_URL` | QuickPizza backend URL. Empty auto-resolves to `http://10.0.2.2:3333` on emulators. Set to your machine's LAN IP for physical devices. |

All four can be overridden at runtime from **Debug → Config** without a
rebuild — overrides apply on the next launch.

---

## Troubleshooting

**No telemetry in Grafana**
- Confirm `OTLP_ENDPOINT`, `OTLP_INSTANCE_ID`, `OTLP_API_KEY` (or their
  Debug-screen overrides) are set.
- Verify the endpoint accepts OTLP/HTTP (not gRPC).
- Use the Debug tab to send a debug log + handled exception and
  confirm they arrive.

**Disk buffering hides recent signals**
- The default ~30–45 s buffering window is intentional for offline
  resilience. Toggle `Disable disk buffering` from the Debug screen for
  live demos.

**App can't reach the backend**
- Emulator: leave `BASE_URL` empty (uses `10.0.2.2:3333`).
- Physical device: set `BASE_URL` to your machine's LAN IP.

**Build fails with `ClassNotFoundException` / dex errors**
- Ensure `gradle.properties` has
  `android.useFullClasspathForDexingTransform=true` (required by
  `opentelemetry-android` with AGP 8.3+).
