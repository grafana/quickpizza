# Android Native Setup Guide

Setup guide for the native Android QuickPizza app (`Mobiles/android/`).

> Companion docs:
> - For the cross-platform observability overview (what each mobile app emits, where it lands), see [`MOBILE_OBSERVABILITY_OVERVIEW.md`](./MOBILE_OBSERVABILITY_OVERVIEW.md).
> - For a higher-level Android README (features + quickstart), see [`../android/README.md`](../android/README.md).
> - For the **Flutter** Android emulator setup, see [`ANDROID_SETUP.md`](./ANDROID_SETUP.md).

---

## Prerequisites

- [Android Studio](https://developer.android.com/studio) (Hedgehog 2023.1.1+ recommended)
- Android SDK with at least API 23 (Android 6.0 Marshmallow) — the app's `minSdk`
- A running QuickPizza backend (see root README)

---

## 1. Create your config file

The app reads `app/src/main/res/raw/config.json` at startup. This file is gitignored so you must create it from the example:

```bash
cp Mobiles/android/app/src/main/res/raw/config.json.example \
   Mobiles/android/app/src/main/res/raw/config.json
```

Edit `config.json`:

```json
{
  "OTLP_ENDPOINT": "https://otlp-gateway-prod-eu-west-0.grafana.net/otlp",
  "OTLP_INSTANCE_ID": "1234567",
  "OTLP_API_KEY": "glc_xxxxxxxxxxxx",
  "BASE_URL": ""
}
```

| Field | Description |
|---|---|
| `OTLP_ENDPOINT` | Your OTLP HTTP base URL (without `/v1/traces`). Leave empty to disable telemetry export. |
| `OTLP_INSTANCE_ID` | Your Grafana Cloud OTLP Gateway instance ID (numeric). |
| `OTLP_API_KEY` | Your Grafana Cloud access token (e.g. `glc_xxxxxxxx`). The app combines it with the instance ID to compute `Authorization: Basic base64(instanceId:apiKey)`. |
| `BASE_URL` | QuickPizza backend URL. **Leave empty** to auto-detect (`http://10.0.2.2:3333` on emulator). Set to your machine's LAN IP for physical devices, e.g. `http://192.168.1.100:3333`. |

> All four URL / credential fields can also be overridden at runtime from the in-app
> **Debug → Config** screen without rebuilding. Overrides take effect after the next
> app restart.

> **Why `10.0.2.2` and not `localhost`?**
> Android emulators route `localhost` to the emulator itself, not the host machine.
> `10.0.2.2` is a special alias for the host's loopback address. The same logic applies to the
> Flutter implementation (see `Mobiles/flutter/lib/core/config/config_service.dart`).

---

## 2. Open the project in Android Studio

```
File → Open → select Mobiles/android/
```

Android Studio will sync the Gradle project automatically.

---

## 3. Run on the Android Emulator

### Option A — Android Studio

1. Create a Virtual Device: **Tools → Device Manager → Create Device**
   - Recommended: Pixel 6, API 35
2. Click **Run ▶** (Shift+F10)

### Option B — Command line

```bash
cd Mobiles/android
./gradlew installDebug
adb shell am start -n com.grafana.quickpizza/.MainActivity
```

---

## 4. Run on a physical device

1. Enable **Developer Options** and **USB Debugging** on the device
2. Connect via USB and accept the debug prompt
3. Set `BASE_URL` in `config.json` to your machine's LAN IP:
   ```json
   { "BASE_URL": "http://192.168.1.100:3333" }
   ```
4. Run from Android Studio or `./gradlew installDebug`

---

## Observability

The app uses [opentelemetry-android](https://github.com/open-telemetry/opentelemetry-android) (`1.2.0`) and exports via OTLP HTTP.

### Signals produced

| Signal | Examples |
|---|---|
| **Spans** | Manual: `auth.login`, `pizza.get_recommendation`, `pizza.rate`. Auto: `GET` (OkHttp HTTP), `AppStart` / `Paused` / `Stopped` (lifecycle). |
| **Logs (`event_name=…`)** | Auto: `screen.view`, `app.jank` (slow-rendering), `session.start`, `rum.sdk.init.*` self-telemetry, `device.crash` (next launch), `device.anr` (runtime). Manual: `exception` (`logger.exception(...)`), `debug.test_event` (Debug screen). |
| **Crashes** | Unhandled exceptions persisted by the OTel-Android `CrashReporter` and exported as `device.crash` log events on the next app launch. |
| **ANRs** | Detected at runtime by the agent; emitted as `device.anr` log events. |
| **Sessions** | 15-minute inactivity timeout, `session.id` stamped on every signal. |

For the full cross-platform telemetry comparison (including how this differs from the iOS, Flutter, and React Native apps), see [`MOBILE_OBSERVABILITY_OVERVIEW.md`](./MOBILE_OBSERVABILITY_OVERVIEW.md).

### Resource attributes

All telemetry carries:

```
service.name        = quickpizza-android
service.namespace   = quickpizza
service.version     = <versionName from build>
deployment.environment = production
```

Plus automatic attributes from opentelemetry-android: `os.name`, `os.version`, `device.model.name`, `android.api_level`, `app.installation.id`.

### Architecture

```
OTelService            — Initializes OpenTelemetryRum agent
AppLogger              — CompositeLogger: Logcat + OtelLogger (OTLP)
AppTracer              — OtelTracer wrapping the Java SDK Tracer
ApiClient (OkHttp)     — Call.Factory wrapped by OkHttpTelemetry for auto HTTP spans
```

---

## Troubleshooting

**Build fails with `ClassNotFoundException` or dex errors**
Ensure `gradle.properties` has `android.useFullClasspathForDexingTransform=true` (required by opentelemetry-android with AGP 8.3+).

**App can't reach the backend**
- Emulator: Make sure QuickPizza is running on the host and `BASE_URL` is empty (uses `10.0.2.2:3333`)
- Physical device: Set `BASE_URL` to your machine's LAN IP

**No telemetry in Grafana**
- Check `OTLP_ENDPOINT`, `OTLP_INSTANCE_ID`, and `OTLP_API_KEY` in `config.json` (or the
  overrides set via the in-app **Debug → Config** screen)
- Verify the endpoint accepts OTLP HTTP (not gRPC)
- Use the **Debug** tab to trigger a test debug log, custom event, or
  handled exception and confirm they arrive

**Telemetry arrives slowly (~30–45 s lag)**
- This is the OTel-Android SDK's disk-buffering window — by design, so signals survive offline periods.
- For live demos, flip **Debug → OpenTelemetry SDK → Disable disk buffering** ON. Latency drops to ~1–6 s, but signals are dropped if the app is offline. Restart the app for the toggle to take effect.

## In-app Debug screen

The **Debug** tab is the same shape as the other QuickPizza mobile apps and exposes:

- Runtime config overrides (backend URL, OTLP endpoint, instance ID, API key) — restart-required.
- Backend error/latency injection toggles (`x-error-record-recommendation`, `x-delay-record-recommendation`, `x-error-get-ingredients`, `x-delay-get-ingredients`).
- Client-side faults (`useV2PizzaSchema` to simulate schema drift, `skipAuthDepInTools`).
- An **OTel SDK** section with the disk buffering toggle described above.
- **Quick Signals** — debug log, error log, custom `debug.test_event`.
- **Handled exception** — calls `logger.exception(...)` so the OTel logger emits an `exception` event.
- **ANR** — blocks the main thread for 6 s; the OTel agent reports `event_name=device.anr`.
- **Crash** — `RuntimeException` and simulated `NullPointerException` variants. The agent persists the crash to disk and the exporter delivers it as `event_name=device.crash` on next launch.

Code: `app/src/main/java/com/grafana/quickpizza/features/debug/DebugScreen.kt`.
