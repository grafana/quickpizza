# QuickPizza iOS Demo App

A native SwiftUI app that demonstrates mobile observability using OpenTelemetry.
It connects to the QuickPizza backend and sends traces/logs to an OTLP collector
(any Grafana Cloud stack you configure — see [Sending Telemetry to Grafana Cloud](#sending-telemetry-to-grafana-cloud)).

> For a cross-platform comparison of all four QuickPizza mobile demos (Flutter, React Native, iOS native, Android native) and what each one emits, see [`../docs/MOBILE_OBSERVABILITY_OVERVIEW.md`](../docs/MOBILE_OBSERVABILITY_OVERVIEW.md). For the iOS instrumentation deep-dive see [`../docs/IOS_OBSERVABILITY_OTEL_GUIDE.md`](../docs/IOS_OBSERVABILITY_OTEL_GUIDE.md). The shared feature spec lives in [`../FEATURES.md`](../FEATURES.md).

---

## Prerequisites

| Requirement                                                       | Notes                               |
| ----------------------------------------------------------------- | ----------------------------------- |
| macOS (Apple Silicon or Intel)                                    | Any recent macOS version            |
| [Xcode](https://apps.apple.com/app/xcode/id497799835)             | Install from Mac App Store (~15 GB) |
| [Docker Desktop](https://www.docker.com/products/docker-desktop/) | For running the backend locally     |
| Git                                                               | To clone this repository            |

> **Note for AI agents:** These are the only tools needed. No CocoaPods, no Homebrew, no Swift Package Manager setup — the Xcode project handles all dependencies automatically.

---

## Quickstart (Simulator + Local Backend)

This is the recommended path. Everything runs on your MacBook.

### Step 1 — Clone the repo

```bash
git clone https://github.com/grafana/mobile-o11y-demo.git
cd mobile-o11y-demo
```

### Step 2 — Start the QuickPizza backend

```bash
docker run --rm -d \
  --name quickpizza \
  -p 3333:3333 \
  ghcr.io/grafana/quickpizza-local:latest
```

Verify it's up:

```bash
curl http://localhost:3333/api/pizza
```

You should get a JSON pizza recommendation back.

### Step 3 — Configure the iOS app

```bash
cd Mobiles/ios
cp Config.xcconfig.example Config.xcconfig
```

Open `Config.xcconfig` in any editor. The defaults work for a local simulator run:

```
# Backend — localhost works for the simulator (not a physical device)
BASE_URL = http:/$()/localhost:3333
PORT = 3333

# OTLP — leave empty to skip telemetry export for now
OTLP_ENDPOINT =
OTLP_INSTANCE_ID =
OTLP_API_KEY =
```

> The `$()` in the URL is an Xcode xcconfig escape for `://` — leave it as-is.

### Step 4 — Build and run on the simulator

The helper script builds the app and launches it in an iPhone simulator automatically:

```bash
cd Mobiles/ios
bash Scripts/sim-run.sh
```

The script will:

1. Auto-detect an available iPhone simulator
2. Build the app with `xcodebuild`
3. Boot the simulator if needed
4. Install and launch the app
5. Stream app logs to your terminal

To target a specific simulator model:

```bash
bash Scripts/sim-run.sh --device "iPhone 16 Pro"
```

List available simulators:

```bash
xcrun simctl list devices available
```

### Step 5 — Open the app

The Simulator app opens automatically. You'll see the QuickPizza home screen.
Tap **Get Pizza** to generate a recommendation — this triggers API calls that are
traced with OpenTelemetry.

---

## Sending Telemetry to Grafana Cloud

To send traces and logs to a Grafana Cloud stack, you need an OTLP endpoint
and an API token.

### Find your OTLP endpoint and credentials

The OTLP endpoint follows the standard Grafana Cloud pattern:

```
https://otlp-gateway-<clusterSlug>.grafana.net/otlp
```

To find your `clusterSlug`, Instance ID, and API token:

1. Go to your Grafana Cloud org page (`https://grafana.com/orgs/<your-org>`)
2. Find the stack and click through to its details — the **cluster slug** and **numeric Instance ID** are listed there
3. Generate an API token with scopes: `metrics:write`, `logs:write`, `traces:write`

### Update Config.xcconfig

The app computes `Authorization: Basic base64(instanceId:apiKey)` at runtime,
so you only need to provide the raw values:

```
BASE_URL = http:/$()/localhost:3333
PORT = 3333

OTLP_ENDPOINT = https://otlp-gateway-<clusterSlug>.grafana.net/otlp
OTLP_INSTANCE_ID = 123456
OTLP_API_KEY = glc_abc123...
```

Then re-run the app:

```bash
bash Scripts/sim-run.sh
```

Traces will appear in **Explore → Tempo** in your Grafana Cloud stack within seconds.
To view native iOS telemetry in a RUM-style dashboard, import and configure the
shared [Mobile OTel RUM dashboard](../docs/MOBILE_OTEL_RUM_DASHBOARD.md).

---

## Opening in Xcode (Alternative to the Script)

If you prefer the Xcode GUI:

```bash
open Mobiles/ios/QuickPizzaIos.xcodeproj
```

Then:

- Select a simulator from the device picker in the toolbar
- Press **Cmd+R** to build and run

The `Config.xcconfig` is automatically picked up by the build system — no extra steps needed.

---

## BrowserStack (Real Device, Optional)

If you want to test on a real iOS device via BrowserStack instead of the simulator:

### 1 — Build an unsigned IPA

BrowserStack re-signs uploaded apps with their own certificate, so no Apple
Developer account or provisioning profile is needed. Build with code signing
disabled:

```bash
cd Mobiles/ios

# Archive without code signing
xcodebuild \
  -project QuickPizzaIos.xcodeproj \
  -scheme QuickPizzaIos \
  -configuration Release \
  -destination "generic/platform=iOS" \
  -archivePath build/QuickPizzaIos.xcarchive \
  CODE_SIGN_IDENTITY="" \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=NO \
  archive

# Package the .app into an IPA manually
mkdir -p build/ipa/Payload
cp -R "build/QuickPizzaIos.xcarchive/Products/Applications/QuickPizzaIos.app" \
  build/ipa/Payload/
cd build/ipa && zip -r ../QuickPizzaIos.ipa Payload && cd ../..
```

### 2 — Upload to BrowserStack App Live

```bash
curl -u "<browserstack_user>:<browserstack_key>" \
  -X POST "https://api-cloud.browserstack.com/app-live/upload" \
  -F "file=@build/ipa/QuickPizzaIos.ipa"
```

The response includes an `app_url` (e.g. `bs://abc123...`). Share that URL or use
the BrowserStack dashboard to launch a session on a real iPhone.

### Backend for BrowserStack

The real device cannot reach `localhost`. You have two options:

**Option A — Use the Grafana-hosted backend:**

Set `BASE_URL` in `Config.xcconfig` to the QuickPizza hosted instance URL
(check with your team for the current URL).

**Option B — Expose localhost with ngrok:**

```bash
brew install ngrok
ngrok http 3333
# Copy the https URL, e.g. https://abc123.ngrok.io
```

Then set:

```
BASE_URL = https:/$()/abc123.ngrok.io
```

---

## How Observability Works

The app uses the [OpenTelemetry Swift SDK](https://github.com/open-telemetry/opentelemetry-swift) (`opentelemetry-swift` 2.3.0) with the `URLSessionInstrumentation`, `Sessions`, and `MetricKitInstrumentation` libraries.

| Signal           | What is instrumented                                                                |
| ---------------- | ----------------------------------------------------------------------------------- |
| **Spans**        | Auto: every `URLSession` call. Manual: `pizza.get_recommendation`, `auth.login`, `pizza.rate`. MetricKit: `MXMetricPayload` spans (Apple's daily aggregated CPU/memory/hangs/hitch data). |
| **Logs**         | Auto: `session.start` / `session.end`, MetricKit `metrickit.diagnostic.{crash,hang,cpu_exception,disk_write_exception}`. Manual: app logs at `DEBUG`/`INFO`/`WARN`/`ERROR`, exception logs (`event_name=exception`), screen views (`event_name=app.screen.view`). |
| **Resource**     | `service.name=quickpizza-ios`, `service.namespace=quickpizza`, `service.version`, `service.build`, `deployment.environment`, `device.id`, `device.model.identifier`, `os.*`, `session.id`, `session.previous_id`, `telemetry.sdk.{language=swift, version=2.3.0}`. |

Configuration is read from `Config.xcconfig` at build time and injected into
`BuildConfig.generated.swift` (auto-generated, gitignored). The `OTelService`
initializes the SDK on app launch using these values.

Runtime overrides for backend URL, OTLP endpoint, and credentials can be set
from the **Debug → Config** screen without rebuilding. These are persisted in
`UserDefaults` and applied on the next app launch via `RuntimeConfigHolder`.

When `OTLP_ENDPOINT` is empty, telemetry is written to the Xcode console only
(via `OSLog`). When set, it is exported over OTLP/HTTP to your collector.

The in-app **Debug** tab additionally lets you simulate backend errors and latency, send test logs / events / handled exceptions, and trigger native crashes (note: MetricKit crash diagnostics are delivered by Apple later and may not appear in Grafana Cloud immediately). See [`../docs/IOS_OBSERVABILITY_OTEL_GUIDE.md § 5`](../docs/IOS_OBSERVABILITY_OTEL_GUIDE.md#5-demo-workflow-customer-facing) for the full demo workflow.

---

## Troubleshooting

**`xcodebuild` not found**

```bash
sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer
sudo xcodebuild -license accept
```

**Simulator not found**

```bash
# Download an iOS runtime in Xcode > Settings > Platforms
xcrun simctl list devices available
```

**App launches but shows network error**

- Make sure the Docker backend is running: `docker ps`
- Make sure it's on port 3333: `curl http://localhost:3333/api/pizza`

**Traces not appearing in Grafana**

- Double-check `OTLP_ENDPOINT` has no trailing slash
- Verify `OTLP_INSTANCE_ID` and `OTLP_API_KEY` are correct in `Config.xcconfig`
- Check the Xcode console for `[OTel]` error messages
