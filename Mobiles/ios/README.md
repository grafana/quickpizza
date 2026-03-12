# QuickPizza iOS Demo App

A native SwiftUI app that demonstrates mobile observability using OpenTelemetry.
It connects to the QuickPizza backend and sends traces/logs to an OTLP collector
(e.g. the `mobileo11y.grafana-dev.net` Grafana Cloud stack).

---

## Prerequisites

| Requirement | Notes |
|---|---|
| macOS (Apple Silicon or Intel) | Any recent macOS version |
| [Xcode](https://apps.apple.com/app/xcode/id497799835) | Install from Mac App Store (~15 GB) |
| [Docker Desktop](https://www.docker.com/products/docker-desktop/) | For running the backend locally |
| Git | To clone this repository |

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
OTLP_AUTH_HEADER =
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

To send traces and logs to the `mobileo11y.grafana-dev.net` Grafana Cloud stack,
you need an OTLP endpoint and an API token.

### Find your OTLP endpoint and credentials

1. Go to your Grafana Cloud stack at `https://mobileo11y.grafana-dev.net`
2. Navigate to **Connections > Add new connection > OpenTelemetry (OTLP)**
3. Note the **OTLP endpoint URL** — it looks like:
   ```
   https://otlp-gateway-<region>.grafana.net/otlp
   ```
4. Generate an API token with `MetricsPublisher` + `TracesPublisher` + `LogsPublisher` scopes
5. Note your **Instance ID** (numeric) shown on the same page

### Generate the auth header

```bash
echo -n "<instance_id>:<api_token>" | base64
```

Example:

```bash
echo -n "123456:glc_abc123..." | base64
# => MTIzNDU2OmdsY19hYmMxMjMu...
```

### Update Config.xcconfig

```
BASE_URL = http:/$()/localhost:3333
PORT = 3333

OTLP_ENDPOINT = https://otlp-gateway-<region>.grafana.net/otlp
OTLP_AUTH_HEADER = Basic MTIzNDU2OmdsY19hYmMxMjMu...
```

Then re-run the app:

```bash
bash Scripts/sim-run.sh
```

Traces will appear in **Explore → Tempo** in your Grafana Cloud stack within seconds.

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

### 1 — Build an IPA

```bash
cd Mobiles/ios

xcodebuild \
  -project QuickPizzaIos.xcodeproj \
  -scheme QuickPizzaIos \
  -configuration Release \
  -destination "generic/platform=iOS" \
  -archivePath build/QuickPizzaIos.xcarchive \
  archive

xcodebuild \
  -exportArchive \
  -archivePath build/QuickPizzaIos.xcarchive \
  -exportPath build/ipa \
  -exportOptionsPlist ExportOptions.plist
```

> You'll need an `ExportOptions.plist` and an Apple Developer account with a valid
> provisioning profile for ad-hoc or enterprise distribution. Without one, use the
> simulator path instead.

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

The app uses the [OpenTelemetry Swift SDK](https://github.com/open-telemetry/opentelemetry-swift).

| Signal | What is instrumented |
|---|---|
| **Traces** | Every API call (pizza recommendations, ratings, auth) |
| **Logs** | App lifecycle events, errors |

Configuration is read from `Config.xcconfig` at build time and injected into
`BuildConfig.generated.swift` (auto-generated, gitignored). The `OTelService`
initialises the SDK on app launch using these values.

When `OTLP_ENDPOINT` is empty, telemetry is written to the Xcode console only
(via `OSLog`). When set, it is exported over OTLP/HTTP to your collector.

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
- Verify the base64 auth header: `echo -n "id:token" | base64`
- Check the Xcode console for `[OTel]` error messages
