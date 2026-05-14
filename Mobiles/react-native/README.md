# QuickPizza React Native Demo App

A React Native mobile application that replicates the QuickPizza web and Flutter app functionality. This app demonstrates Grafana Faro SDK integration for mobile observability.

> For a cross-platform comparison of all four QuickPizza mobile demos (Flutter, React Native, iOS native, Android native) and what each one emits, see [MOBILE_OBSERVABILITY_OVERVIEW.md](../docs/MOBILE_OBSERVABILITY_OVERVIEW.md). The shared feature spec lives in [FEATURES.md](../FEATURES.md).

## Features

- Get pizza recommendations with one click
- Rate pizzas (Love it! or No thanks)
- User login and profile management
- Advanced options for customizing pizza recommendations
- View your pizza ratings history
- In-app **Debug** tab for runtime config overrides, backend error/latency injection, client-side fault simulation, sending test logs and custom events (`debug_custom_event`), reporting handled and unhandled exceptions, and triggering native crashes that arrive in Faro as `kind=exception, type=crash` on the next launch.

## Prerequisites

- Node.js >= 22
- Yarn
- React Native development environment ([setup guide](https://reactnative.dev/docs/environment-setup))
- QuickPizza backend running (default: `http://localhost:3333`)

## Setup

### 1. Install dependencies

```bash
yarn install
```

### 2. Configure the app

Copy the example config and add your values (same approach as the Flutter app):

```bash
cp config.json.example config.json
```

Edit `config.json`:

- `FARO_COLLECTOR_URL` (required): Your Grafana Faro collector URL for observability
- `BASE_URL` (optional): Backend API URL. Leave empty for emulators (uses 10.0.2.2 for Android, localhost for iOS)
- `PORT` (optional): Backend port, defaults to 3333

For physical devices, set `BASE_URL` to your machine's IP (e.g. `http://192.168.1.100:3333`).

### 3. iOS: Install CocoaPods

```bash
cd ios && pod install && cd ..
```

### 4. Source map uploads

**What problem this solves:** In a **release** build, Hermes runs **bytecode**, not your original JavaScript. Crash and error stacks from the device therefore point at **positions inside that bytecode**. Grafana can only translate those back to real **`src/` files and line numbers** if you also send a **source map** that was built for that exact binary, and if the app reports the same **bundle id** as that map (`meta.app.bundleId` — set by the Metro plugin). See [Frontend Observability](https://grafana.com/docs/grafana-cloud/monitor-applications/frontend-observability/) for product context.

**What happens in one pass (simple picture):**

1. **Metro** bundles your JS (with `@grafana/faro-metro-plugin` in `metro.config.js` so the bundle id is baked in and maps stay compatible with the next steps).
2. **Hermes** compiles that JS bundle to bytecode for the device.
3. The native build runs **`compose-source-maps.js`**, which **merges** Metro’s map with Hermes’s map into one **composed** file. That composed file is what maps **runtime bytecode locations** back to your sources — not the intermediate Metro-only map alone.
4. **Upload:** that composed file is sent to Grafana’s source map API with **`faro-cli metro upload`**, keyed by your bundle id so symbolication can look it up.

| Part of the stack | What you need to know |
| --- | --- |
| **Metro + `@grafana/faro-metro-plugin`** | Configures bundling and the bundle id; keeps maps in the right shape before Hermes and compose run. |
| **Android** | **`@grafana/faro-react-native` is autolinked** like any other native module. For **release** builds, the SDK wires in a step that runs **after** the composed map exists and calls **`faro-cli metro upload`** for you (using `index.android.bundle.map`). Set the `FARO_*` env vars when you build so that step can run. |
| **iOS** | **`@grafana/faro-react-native` is autolinked** via CocoaPods. **`pod install`** adds a **`[Faro] Upload composed source map (Release)`** Run Script phase that runs the same `faro-upload-source-map` shim (→ **`faro-cli metro upload`**) after Metro + Hermes + compose produce **`main.jsbundle.map`**. Export the same **`FARO_*`** variables for the build environment you use. **Release** should define **`SOURCEMAP_FILE`** in Xcode so `react-native-xcode.sh` writes the composed map (this demo sets it on the Release configuration — see iOS steps below). |

Deeper technical notes: [`@grafana/faro-metro-plugin` README](../../../faro-javascript-bundler-plugins/packages/faro-metro-plugin/README.md).

#### Configure

Just for the first time you need to:

From `Mobiles/react-native/`:

```bash
cp sourcemaps.config.example.json sourcemaps.config.json
```

Edit **`sourcemaps.config.json`** (gitignored, like `config.json`):

| Field | Purpose |
| --- | --- |
| `appName` | Must match `app.name` in `initializeFaro` (`src/bootstrap.ts`). |
| `endpoint`, `appId`, `stackId` | **Frontend Observability → your app → Settings → Source maps** (not the Faro collector URL). |
| `apiKey` | Bearer token for the source map API (optional if you use env only). |
| `bundleId` | Optional default id; release builds usually set `FARO_BUNDLE_ID` in the shell so it matches the uploaded map. |

For **Android** release, export these in the same shell where you run **`yarn android --mode=release`**. 

For **iOS** release, export them in the same shell where you run **`yarn ios -- --mode Release`** (or inject them into CI **`xcodebuild`**) so the autolinked upload step can run **`faro-upload-source-map`**.

`FARO_BUNDLE_ID`, `FARO_SOURCEMAP_ENDPOINT`, `FARO_SOURCEMAP_APP_ID`, `FARO_SOURCEMAP_STACK_ID`, `FARO_SOURCEMAP_API_KEY`.

They override the JSON values when set. Use **one** bundle id per build you ship; changing the id means uploading a new map.

#### Android — recommended flow (build + upload + verify)

Run everything from **`Mobiles/react-native/`**.

1. **Produce a release install and upload the map** — Metro, Hermes, compose, then the upload step injected by autolinking:

   ```bash
   export FARO_BUNDLE_ID="$(git rev-parse --short HEAD)-$(date +%s)"
   export FARO_SOURCEMAP_ENDPOINT="https://<your-stack>.grafana.net/api/v1"
   export FARO_SOURCEMAP_APP_ID="<app-id>"
   export FARO_SOURCEMAP_STACK_ID="<stack-id>"
   export FARO_SOURCEMAP_API_KEY="<token>"
   export ENABLE_FARO_PAYLOAD_DIAGNOSTICS=true

   yarn install   # after changing faro-metro-plugin / faro-cli deps
   yarn android --mode=release
   ```

   **What you should see:** the build finishes without `[Faro] Skipping composed source map upload` unless a required env var is missing. The composed map path is `android/app/build/generated/sourcemaps/react/release/index.android.bundle.map`.

2. **Check the device payload (optional but fast)** — confirms the bundle id and frame filenames are usable for symbolication:

   ```bash
   adb logcat -d | rg '\[Faro diagnostics\]'
   ```

   **What to look for:** `[Faro diagnostics][init]` includes your `meta.app.bundleId` matching `FARO_BUNDLE_ID`; `[Faro diagnostics][exception]` lists frames with `index.android.bundle`, not only raw `address at …` lines.

3. **Trigger an error in the app** — open **Debug** → under **Exceptions** tap **Handled exception** (or provoke another JS error you care about).

4. **Check Grafana** — in **Frontend Observability** for this app, open the error: stack frames should point at **`src/...`** files and line numbers, not Hermes offsets. If you still see offsets, the bundle id in telemetry does not match the uploaded map or the upload failed (re-check step 1 env vars and **`[Faro]`** lines in the build output).

**Useful toggles**

- Skip upload while iterating: `FARO_SKIP_SOURCEMAP_UPLOAD=1 yarn android --mode=release`.
- Re-upload the same composed map manually (same env vars):

  ```bash
  npx faro-cli metro upload \
    --map android/app/build/generated/sourcemaps/react/release/index.android.bundle.map \
    --endpoint "$FARO_SOURCEMAP_ENDPOINT" \
    --app-id "$FARO_SOURCEMAP_APP_ID" \
    --stack-id "$FARO_SOURCEMAP_STACK_ID" \
    --api-key "$FARO_SOURCEMAP_API_KEY" \
    --bundle-id "$FARO_BUNDLE_ID"
  ```

#### iOS — release build, upload, verify

Use the **same** `FARO_*` variables and **`sourcemaps.config.json`** as on Android. After **`cd ios && pod install`**, autolinking adds **`[Faro] Upload composed source map (Release)`** to your app target. 

- **Debug** builds skip upload; 
- **Release** runs the same `faro-upload-source-map` flow as Android once the composed map exists.

**Prerequisite:** This app’s Xcode **Release** configuration sets **`SOURCEMAP_FILE`** so Hermes produces a composed **`main.jsbundle.map`**. Copy that setting into other apps if you reuse this pattern.

1. **Produce a Release build** (from `Mobiles/react-native/`):

   ```bash
   export FARO_BUNDLE_ID="$(git rev-parse --short HEAD)-$(date +%s)"
   export FARO_SOURCEMAP_ENDPOINT="https://<your-stack>.grafana.net/api/v1"
   export FARO_SOURCEMAP_APP_ID="<app-id>"
   export FARO_SOURCEMAP_STACK_ID="<stack-id>"
   export FARO_SOURCEMAP_API_KEY="<token>"
   export ENABLE_FARO_PAYLOAD_DIAGNOSTICS=true

   cd ios && pod install && cd ..
   yarn ios -- --mode Release
   ```

   **What you should see:** the build log should **not** end with **`[Faro] Skipping composed source map upload`** unless a `FARO_*` var is missing, **`FARO_SKIP_SOURCEMAP_UPLOAD`** is set, **`SOURCEMAP_FILE`** is unset in that configuration, or the composed map path is wrong.

2. **Check logs** — for example:

   ```bash
   npx react-native log-ios | rg 'Faro diagnostics'
   ```

   **What to look for:** bundle id on init; exception frames referencing **`main.jsbundle`** where relevant for symbolication.

3. **In the app**, trigger **Debug → Handled exception** (or another JS error).

4. **In Grafana**, open the error under Frontend Observability — frames should resolve to **`src/...`**.

**Useful toggles**

- **`FARO_SKIP_SOURCEMAP_UPLOAD=1`** in the environment for the Release build skips upload (offline iteration).
- **Manual re-upload** with **`npx faro-cli metro upload --map …`** is optional if you need a CI-only retry; autolinking normally uploads using **`SOURCEMAP_FILE`**.

## Running the app

### Start the QuickPizza backend

**Option A – Monolithic (simple):**

```bash
docker run --rm -it -p 3333:3333 ghcr.io/grafana/quickpizza-local:latest
```

**Option B – Microservices with Grafana Cloud observability** (from the `mobile-o11y-demo` root):

Create a `.env` file with `GRAFANA_CLOUD_STACK` and `GRAFANA_CLOUD_TOKEN`, then:

```bash
docker compose -f compose.grafana-cloud.microservices.yaml up -d
```

**Database / seed issues:** remove the Postgres data volume for the stack you actually started, then bring it up again so migrations and seed re-run:

- **Microservices:** `docker compose -f compose.grafana-cloud.microservices.yaml down -v`, then `docker compose -f compose.grafana-cloud.microservices.yaml up -d` (or the same pattern with `compose.grafana-local-stack.microservices.yaml` if that is what you run).
- **Monolithic (Docker Compose):** `docker compose -f compose.grafana-cloud.monolithic.yaml down -v`, then `up -d` with that file again (or `compose.grafana-local-stack.monolithic.yaml` if you use the local stack).
- **Monolithic (`docker run`, Option A):** there is no Compose volume; stop the container and run the `docker run` line again (the default image typically uses an in-memory DB per container).

If you build QuickPizza from this repo, run `make docker-build` so your local image picks up backend or seed changes before `up` again.

### Run the app

```bash
# Start Metro bundler (in one terminal)
yarn start

# Run on iOS (in another terminal)
yarn ios
# or
./scripts/run-ios.sh

# Run on Android
yarn android
# or
./scripts/run-android.sh
```

## Default login credentials

- Username: `default`
- Password: `12345678`

## Faro SDK

This app depends on `@grafana/faro-react-native` and `@grafana/faro-react-native-tracing` at `1.0.0-alpha.1` from npm (`package.json`; the git tag may be `v1.0.0-alpha.1`). After those versions are published, run `yarn install` here and commit the updated `yarn.lock` (with resolved URLs and integrity hashes). Until then, `yarn install` will 404 against the public registry.

In Grafana Cloud the app reports as `app_name=QuickPizza_ReactNative` (Faro app id `123` on the demo stack). Telemetry includes auto fetch + XMLHttpRequest tracing, `app_lifecycle_changed`, `view_changed`, custom business measurements (`pizza.recommendation`, `pizza.rating`), and native crash capture via Faro CrashKit.

**Known issue:** RN exception logs occasionally include `console.error: Faro is already registered. Either add instrumentations, transports etc. to the global faro instance or use the "isolate" property`. This appears to come from a hot-reload / re-bootstrap path in `src/bootstrap.ts`. It does not affect telemetry flow but pollutes the error stream.

## Project structure

```
src/
├── core/           # Config, API client, o11y layer, theme
├── features/       # Auth, pizza, profile, about
├── navigation/     # React Navigation setup
└── bootstrap.ts    # Faro initialization
```

## E2E tests

End-to-end tests use [Arbigent](https://github.com/takahirom/arbigent) (AI-powered UI automation) and run on an Android emulator.

### Prerequisites

- Android emulator running with the app installed
- QuickPizza backend running (e.g. `docker run --rm -it -p 3333:3333 ghcr.io/grafana/quickpizza-local:latest`)
- `OPENAI_API_KEY` environment variable set (Arbigent uses OpenAI for AI-driven test execution)
- `adb`, `unzip`, and either `wget` or `curl` installed

### Running E2E tests locally

1. **Start the QuickPizza backend** (in one terminal):
  ```bash
   docker run --rm -it -p 3333:3333 ghcr.io/grafana/quickpizza-local:latest
  ```
2. **Build and run the app on an Android emulator** (in another terminal):
  ```bash
   yarn start
   # In another terminal:
   yarn android
  ```
3. **Export your OpenAI API key** and run the E2E tests:
  ```bash
   export OPENAI_API_KEY='your-api-key'
   ./scripts/e2e/run_e2e_tests.sh
  ```

Results are written to `arbigent-result/` (including an HTML report when Node.js is available).

### Optional: custom backend URL

If your backend runs elsewhere, set `QUICKPIZZA_BACKEND_URL` before running:

```bash
export QUICKPIZZA_BACKEND_URL='http://192.168.1.100:3333'
./scripts/e2e/run_e2e_tests.sh
```

## API endpoints

- `GET /api/quotes` - Random quote
- `GET /api/tools` - Pizza tools
- `POST /api/pizza` - Pizza recommendation
- `POST /api/ratings` - Submit rating
- `GET /api/ratings` - User ratings
- `DELETE /api/ratings` - Clear ratings
- `POST /api/users/token/login` - Login

