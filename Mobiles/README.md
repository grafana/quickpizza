# QuickPizza Mobile Demos

Four QuickPizza mobile apps for demoing mobile observability with Grafana. They
share the same screens and backend; they differ in the telemetry SDK.

| App | SDK | Sends to | Run guide |
| --- | --- | --- | --- |
| Flutter (Android + iOS) | Grafana Faro | Faro collector `/collect/<appKey>` | [flutter/README.md](./flutter/README.md) |
| React Native (Android + iOS) | Grafana Faro | Faro collector `/collect/<appKey>` | [react-native/README.md](./react-native/README.md) |
| iOS native (SwiftUI) | OpenTelemetry Swift, via the local Grafana package | Faro collector `/otlp/<appKey>` (OTLP/HTTP) | [ios/README.md](./ios/README.md) |
| Android native (Compose) | OpenTelemetry Android, via the local Grafana package | Faro collector `/otlp/<appKey>` (OTLP/HTTP) | [android/README.md](./android/README.md) |

All four land in Grafana Cloud **Frontend Observability**, one app per key.

Want the smallest possible setup instead of a full demo? [quickstart/](./quickstart/README.md) has
tiny single-screen apps that use plain OpenTelemetry, with no Grafana package, and are meant to be copied.

## Run a demo in 3 steps

### Step 1 — Start the backend

Every app needs the QuickPizza backend. Build the mobile image from this
checkout and run it:

```bash
docker build -t quickpizza-mobile-local:development .
docker run --rm -d --name quickpizza -p 3333:3333 \
  quickpizza-mobile-local:development
curl --fail -i http://localhost:3333/healthz   # expect HTTP 200
```

Use `quickpizza-mobile-local` for mobile work; the upstream `quickpizza-local`
image belongs to the k6/web workshops. To run the backend with its own
observability through Docker Compose, select the local image:

```bash
export QUICKPIZZA_IMAGE=quickpizza-mobile-local:development
docker compose -f compose.grafana-cloud.microservices.yaml up -d
```

The standalone container keeps its database in memory, so restarting it resets
users and ratings. With Compose, run `docker compose -f <file> down -v` first.

To send telemetry to two stacks at once, use
[dual-stack telemetry](#optional-dual-stack-telemetry) instead of this step.

### Step 2 — Connect to Grafana Cloud

- **Flutter / React Native:** a collector URL (`FARO_COLLECTOR_URL` or its
  per-platform variant) is **required**. These apps throw at startup without
  one, even for a local-only demo.
- **iOS / Android native:** optional. With the OTLP fields empty the apps run,
  but OpenTelemetry is not initialized and sends nothing.

Create the app's config file from its template (from the repository root), then
add the URL as described in [Connect to Grafana Cloud](./docs/CONNECT_GRAFANA_CLOUD.md):

```bash
cp -n Mobiles/ios/Config.xcconfig.example Mobiles/ios/Config.xcconfig  # iOS native
cp -n Mobiles/android/config.json.example Mobiles/android/app/src/main/res/raw/config.json  # Android native
cp -n Mobiles/flutter/config.json.example Mobiles/flutter/config.json  # Flutter
cp -n Mobiles/react-native/config.json.example Mobiles/react-native/config.json  # React Native
```

Copy only the ones you need. The files are gitignored, and `cp -n` leaves an
existing file alone, so running it again (here or in a platform README) keeps your URL.

### Step 3 — Run an app

Each platform README has the toolchain prerequisites and full steps. From the
repository root:

- **iOS native** (Xcode): `bash Mobiles/ios/Scripts/sim-run.sh`
- **Android native** (Android Studio + emulator): `(cd Mobiles/android && ./gradlew installDebug) && adb shell am start -n com.grafana.quickpizza.android/com.grafana.quickpizza.MainActivity`
- **Flutter** (Flutter SDK + Xcode or Android Studio): see [flutter/README.md](./flutter/README.md)
- **React Native** (Node 24.5+, Yarn, CocoaPods for iOS): see [react-native/README.md](./react-native/README.md)

## Shared basics

- **Login:** tap the Profile icon on Home, then use `default` / `12345678`.
  This shared account cannot delete ratings; use the seeded `studio-user` /
  `k6studiorocks` account to demo **Clear Ratings**.
- **Backend URL:** the default `BASE_URL` works on emulators and simulators:
  `http://10.0.2.2:3333` on the Android emulator and `http://localhost:3333` on
  the iOS simulator. For a physical device, follow the platform README.
- **Debug tab:** every app has an in-app Debug screen to override config,
  inject backend errors and latency, and trigger logs, handled exceptions, and
  native crashes. Use it to generate telemetry during a demo. See
  [the shared Debug screen](./docs/MOBILE_OBSERVABILITY_OVERVIEW.md#the-shared-debug-screen).
- **Android emulator:** `Mobiles/scripts/ensure-android-emulator.sh` boots an
  AVD or waits until one is adb-ready. Pass `--avd <name>` when several exist.

## Optional dual-stack telemetry

An alternative to Step 1 that sends every app's telemetry to two saved Grafana
Cloud stacks. Stop the standalone backend first (`docker stop quickpizza`),
then from the repository root:

```bash
python3 Mobiles/telemetry/setup.py     # backend + forwarders, configures all apps
python3 Mobiles/telemetry/teardown.py  # stop
```

See [telemetry/README.md](./telemetry/README.md) for options and IDE launch.

## Docs

| I want to… | Read |
| --- | --- |
| Set up plain OpenTelemetry Swift from scratch (no Grafana package) | [quickstart/ios/README.md](./quickstart/ios/README.md) |
| Set up plain OpenTelemetry Android from scratch (no Grafana package) | [quickstart/android/README.md](./quickstart/android/README.md) |
| Connect an app to a Grafana Cloud stack | [docs/CONNECT_GRAFANA_CLOUD.md](./docs/CONNECT_GRAFANA_CLOUD.md) |
| See what each app emits and where it lands | [docs/MOBILE_OBSERVABILITY_OVERVIEW.md](./docs/MOBILE_OBSERVABILITY_OVERVIEW.md) |
| Read the shared screens and workflows spec | [FEATURES.md](./FEATURES.md) |
| Import the native OTel RUM dashboard (legacy gateway path) | [docs/MOBILE_OTEL_RUM_DASHBOARD.md](./docs/MOBILE_OTEL_RUM_DASHBOARD.md) |
| Go deeper on iOS OTel instrumentation | [docs/IOS_OBSERVABILITY_OTEL_GUIDE.md](./docs/IOS_OBSERVABILITY_OTEL_GUIDE.md) |
| Understand the iOS app architecture | [docs/IOS_APP_ARCHITECTURE.md](./docs/IOS_APP_ARCHITECTURE.md) |
| Use the local Grafana OTel packages | [iOS package](./ios/grafana-opentelemetry-ios/README.md), [Android library](./android/grafana-opentelemetry-android/README.md) |
| Run the cross-platform E2E tests | [e2e/README.md](./e2e/README.md) |
| Track OTel mobile SDK gaps | [docs/OTEL_MOBILE_MATURITY.md](./docs/OTEL_MOBILE_MATURITY.md) |
