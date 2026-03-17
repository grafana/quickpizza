# Android Native Setup Guide

Setup guide for the native Android QuickPizza app (`Mobiles/android/`).

> For the **Flutter** Android emulator setup, see [ANDROID_SETUP.md](./ANDROID_SETUP.md).

---

## Prerequisites

- [Android Studio](https://developer.android.com/studio) (Hedgehog 2023.1.1+ recommended)
- Android SDK with at least API 21 (Android 5.0 Lollipop) — the app's `minSdk`
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
  "OTLP_AUTH_HEADER": "Basic <base64(instanceId:apiKey)>",
  "BASE_URL": ""
}
```

| Field | Description |
|---|---|
| `OTLP_ENDPOINT` | Your OTLP HTTP base URL (without `/v1/traces`). Leave empty to disable telemetry export. |
| `OTLP_AUTH_HEADER` | Authorization header value, e.g. `Basic <base64>` or `Bearer <token>`. |
| `BASE_URL` | QuickPizza backend URL. **Leave empty** to auto-detect (`http://10.0.2.2:3333` on emulator). Set to your machine's LAN IP for physical devices, e.g. `http://192.168.1.100:3333`. |

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
| **Traces** | `auth.login`, `pizza.get_recommendation`, `pizza.rate`, auto-instrumented HTTP spans from OkHttp |
| **Logs** | Structured app logs, exception records with `exception.stacktrace` |
| **Crashes** | Unhandled exceptions captured by the crash instrumentation |
| **Sessions** | 15-minute inactivity timeout, `session.id` stamped on all telemetry |

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
- Check `OTLP_ENDPOINT` and `OTLP_AUTH_HEADER` in `config.json`
- Verify the endpoint accepts OTLP HTTP (not gRPC)
- Use the **Debug** tab to trigger a test exception and confirm it arrives

**`EncryptedSharedPreferences` error on first install**
Clear the app data: **Settings → Apps → QuickPizza → Clear Data**
