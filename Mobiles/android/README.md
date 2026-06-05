# QuickPizza Android Demo App

A native Kotlin / Jetpack Compose app that demonstrates mobile observability
using the `[opentelemetry-android](https://github.com/open-telemetry/opentelemetry-android)`
RUM agent. It connects to the QuickPizza backend and exports traces and
logs over OTLP/HTTP to Grafana Cloud.

For setup details (Android Studio, SDK, emulator, physical devices) see
`[../docs/ANDROID_NATIVE_SETUP.md](../docs/ANDROID_NATIVE_SETUP.md)`.

For the cross-platform observability overview (Faro vs OTel, what each
platform emits, dashboards) see
`[../docs/MOBILE_OBSERVABILITY_OVERVIEW.md](../docs/MOBILE_OBSERVABILITY_OVERVIEW.md)`.

> **Not the same as the Flutter Android app.** The Flutter implementation
> lives at `[../flutter/](../flutter/)`. This directory is the **native**
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
  ghcr.io/grafana/quickpizza-mobile-local:latest

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

## Release build and Android symbols

Release builds enable R8 (`isMinifyEnabled = true`) and emit native debug
symbols (`ndk.debugSymbolLevel = FULL`). The `**com.grafana.faro`** Gradle plugin
(`app/build.gradle.kts`) uploads symbolication artifacts automatically after
`assembleRelease`, `bundleRelease`, or `**installRelease**` — no manual
`faro-cli` step is required.


| Artifact       | Path (under `app/build/outputs/`)                       |
| -------------- | ------------------------------------------------------- |
| R8 mapping     | `mapping/release/mapping.txt`                           |
| Native symbols | `native-debug-symbols/release/native-debug-symbols.zip` |


### How release builds link to readable crash reports

Each shipped Android release gets a **release id** — a short label that
combines the app package name, build number, and version string. For this
demo that id is `**com.grafana.quickpizza@1@1.0`**.

Think of it in three steps:

1. **At build time** (your CI or laptop, not on users’ phones), the Gradle
  plugin uploads debug files for that release to Grafana — the files that
   turn obfuscated crash output back into real class and file names.
2. **At runtime**, the installed app only sends lightweight error reports.
  Each report includes the same release id so Grafana knows *which* build
   produced the crash.
3. **In Grafana**, Frontend Observability uses that id to find the files
  uploaded in step 1 and show a **readable stack trace** instead of
   scrambled names like `a5.r0`.

The release id is saved locally as `app/build/faro/bundle-id-release.txt` so
build tooling and uploads stay in sync. Engineers: the app emits this id as
`faro.app.bundleId` at runtime; `service.version` remains the human-readable
version (`1.0`) for dashboards.

> **Also in this repo — the React Native demo** (`[../react-native/](../react-native/)`):
> same three-step flow and the same release id per build. The difference is
> *what* gets uploaded at build time. The React Native app is written in
> JavaScript *and* native Android code, so its release pipeline uploads debug
> files for **both** layers under one id. **This app** is native Kotlin only,
> so it uploads debug files for the **Android/native** layer alone. Details:
> `[../react-native/README.md](../react-native/README.md)`.

### Configure upload credentials

Set these in the shell or CI (never hardcode the API key in Gradle):


| Variable                  | Source in Grafana                                                             |
| ------------------------- | ----------------------------------------------------------------------------- |
| `FARO_SOURCEMAP_ENDPOINT` | Frontend Observability → your app → **Settings → Source maps** (API base URL) |
| `FARO_SOURCEMAP_APP_ID`   | App id                                                                        |
| `FARO_SOURCEMAP_STACK_ID` | Stack id                                                                      |
| `FARO_SOURCEMAP_API_KEY`  | Upload token                                                                  |


```kotlin
// app/build.gradle.kts (already wired)
faro {
    endpoint.set(System.getenv("FARO_SOURCEMAP_ENDPOINT"))
    appId.set(System.getenv("FARO_SOURCEMAP_APP_ID"))
    stackId.set(System.getenv("FARO_SOURCEMAP_STACK_ID"))
    apiKey.set(System.getenv("FARO_SOURCEMAP_API_KEY"))
}
```

If any variable is missing, `faroUploadSymbolsRelease` **warns and skips** — the
build still succeeds (useful for local debug builds without upload access). Set
`faro { enabled = false }` to disable uploads entirely.

### Build and upload

```bash
cd Mobiles/android
export FARO_SOURCEMAP_ENDPOINT="https://<your-stack>.grafana.net/api/v1"
export FARO_SOURCEMAP_APP_ID="<app-id>"
export FARO_SOURCEMAP_STACK_ID="<stack-id>"
export FARO_SOURCEMAP_API_KEY="<token>"

./gradlew assembleRelease   # or installRelease to push to a device
```

**What runs on release:** `faroWriteBundleIdRelease` → build →
`faroUploadSymbolsRelease` (in-JVM upload to
`POST …/app/{appId}/symbols/android/{bundleId}`). Look for `[Faro]` lines in
Gradle output.

Confirm artifacts from the **same** build:

```bash
ls -l app/build/faro/bundle-id-release.txt
ls -l app/build/outputs/mapping/release/mapping.txt
ls -l app/build/outputs/native-debug-symbols/release/native-debug-symbols.zip
```

Manual retry outside Gradle (optional): `faro-cli android upload` with the same
`FARO_SOURCEMAP_*` env vars and `--application-id` / `--version-code` /
`--version-name` matching `bundle-id-release.txt` (see
`[faro-cli` `android upload](https://github.com/grafana/faro-javascript-bundler-plugins/tree/main/packages/faro-cli)`).

**Verify in Grafana:** install the release build (`./gradlew installRelease`),
open the app, trigger **Debug → Crash (RuntimeException)**, relaunch, and check
Frontend Observability — the crash should show real Kotlin file names, not
scrambled labels like `a5.r0`.

---

## Features

The user-facing screens (Home, Login, Profile, About, Debug) are aligned
with the other QuickPizza mobile apps. See
`[../FEATURES.md](../FEATURES.md)` for the shared feature spec.

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

The app uses `[opentelemetry-android](https://github.com/open-telemetry/opentelemetry-android)`
1.2.0-alpha and exports via OTLP/HTTP. Init lives in
`app/src/main/java/com/grafana/quickpizza/core/o11y/OTelService.kt`.


| Signal    | Examples                                                                                                                                                                                                                                                            |
| --------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Spans** | `GET` (auto OkHttp), `AppStart` / `Paused` / `Stopped` (auto lifecycle), `pizza.get_recommendation` / `auth.login` / `pizza.rate` (manual)                                                                                                                          |
| **Logs**  | `screen.view` (auto), `app.jank` (auto, slow rendering), `session.start` (auto), `rum.sdk.init.`* (auto SDK self-telemetry), `exception` (manual `logger.exception`), `device.crash` (auto, next launch), `device.anr` (auto, runtime), `debug.test_event` (manual) |


Resource attributes:

```
service.name             = quickpizza-android   (logical service — not the package)
service.namespace        = quickpizza
service.version          = 1.0                  (versionName)
faro.app.bundleId        = com.grafana.quickpizza@1@1.0  (symbols lookup key: applicationId@versionCode@versionName)
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

- **Dashboard:** import and configure the shared [Mobile OTel RUM dashboard](../docs/MOBILE_OTEL_RUM_DASHBOARD.md)
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


| Field              | Description                                                                                                                            |
| ------------------ | -------------------------------------------------------------------------------------------------------------------------------------- |
| `OTLP_ENDPOINT`    | OTLP/HTTP base URL (without `/v1/traces`). Empty disables export.                                                                      |
| `OTLP_INSTANCE_ID` | Numeric Grafana Cloud OTLP gateway instance ID.                                                                                        |
| `OTLP_API_KEY`     | Grafana Cloud access token (combined with the instance ID into `Authorization: Basic`).                                                |
| `BASE_URL`         | QuickPizza backend URL. Empty auto-resolves to `http://10.0.2.2:3333` on emulators. Set to your machine's LAN IP for physical devices. |


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

