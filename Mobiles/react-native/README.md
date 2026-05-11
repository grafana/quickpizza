# QuickPizza React Native Demo App

A React Native mobile application that replicates the QuickPizza web and Flutter app functionality. This app demonstrates Grafana Faro SDK integration for mobile observability.

> For a cross-platform comparison of all four QuickPizza mobile demos (Flutter, React Native, iOS native, Android native) and what each one emits, see `[../docs/MOBILE_OBSERVABILITY_OVERVIEW.md](../docs/MOBILE_OBSERVABILITY_OVERVIEW.md)`. The shared feature spec lives in `[../FEATURES.md](../FEATURES.md)`.

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

- **FARO_COLLECTOR_URL** (required): Your Grafana Faro collector URL for observability
- **BASE_URL** (optional): Backend API URL. Leave empty for emulators (uses 10.0.2.2 for Android, localhost for iOS)
- **PORT** (optional): Backend port, defaults to 3333

For physical devices, set `BASE_URL` to your machine's IP (e.g. `http://192.168.1.100:3333`).

### Source map uploads (Metro / `@grafana/faro-metro-plugin`)

`metro.config.js` reads `**sourcemaps.config.json`** (gitignored, like `config.json`) for `appName`, `endpoint`, `appId`, `stackId`, and optionally `**apiKey**` (Faro source map API bearer) and `**bundleId**` (must match the release build you ship). Create yours from the example:

```bash
cp sourcemaps.config.example.json sourcemaps.config.json
```

**Why not `config.json`?** `config.json` is for **app runtime** (collector URL, backend base URL) and is read by the JS bundle on device. The source map **upload API** is used only by **Metro** at build time, so those fields belong in `**sourcemaps.config.json`** next to `appId` / `stackId` for the same API.

**Precedence:** `FARO_SOURCEMAP_API_KEY` and `**FARO_BUNDLE_ID`** (or `FARO_BUNDLE_ID_<CLEAN_APP_NAME>`) **override** file values when set—use that in CI. Env `**FARO_SOURCEMAP_ENDPOINT`**, `**FARO_SOURCEMAP_APP_ID**`, `**FARO_SOURCEMAP_STACK_ID**` also override the JSON. Set `**FARO_METRO_VERBOSE=1**` for `**[Faro]**` upload logs.

**Frontend Knowledge Workbench / local plugin dev:** this app’s `**package.json`** uses `**resolutions**` so `**@grafana/faro-bundlers-shared**` resolves to the sibling repo `**faro-javascript-bundler-plugins/packages/faro-bundlers-shared**`. That keeps Metro uploads working for React Native map names like `**index.android.bundle.map**`. After updating that submodule, run `**yarn install**` here. If you only consume published packages, use a `**@grafana/faro-bundlers-shared**` release that includes the `***.bundle.map` / `*.jsbundle.map**` source map filename pattern.

**Bundle / map `file` field:** `react-native bundle` has **no flag** for the source map top-level `**file`**. This repo sets `**sourceMapFile**` in `**metro.config.js**` (default `index.android.bundle` on Android; use `**FARO_SOURCEMAP_FILE**` or `**FARO_PLATFORM=ios**` for `main.jsbundle`). `**initializeFaro**` uses `**releaseBundleFilename**` with the same basenames so Hermes stacks resolve to the uploaded map. Re-run the bundle after changing either side.

#### Manual test: release bundle + source map (Path A)

Run these steps from **this directory** (`Mobiles/react-native` — the folder that contains `package.json`, `index.js`, and `metro.config.js`), not from `android/` or `ios/`. This produces a release JS bundle and source map the same way Metro does for a release build, so you can validate `**@grafana/faro-metro-plugin`** (preamble, map, upload URL).

1. Ensure `**sourcemaps.config.json**` exists (see above). You can put `**apiKey**` and `**bundleId**` there for a file-only workflow, or leave them empty and use environment variables. For a real upload (`2xx` from the source map API), set a reachable `**endpoint**`. With a placeholder host you can still confirm the plugin **attempts** `POST …/app/{appId}/sourcemaps/{bundleId}` from the logs.
2. **Bundle id:** Prefer `**bundleId`** in `**sourcemaps.config.json**` so it stays with the rest of the upload settings. Alternatively set `**FARO_BUNDLE_ID**` (or per-app `**FARO_BUNDLE_ID_<CLEAN_APP_NAME>**`) in the environment—for example in CI:
  ```bash
   export FARO_BUNDLE_ID="manual-$(git rev-parse --short HEAD)-$$"
  ```

##### Android

1. **Build** (no secrets on the command line): with `**apiKey`**, `**bundleId**`, `**endpoint**`, `**appId**`, and `**stackId**` set in `**sourcemaps.config.json**` as needed, run:
  ```bash
   mkdir -p dist/android-release

   npx react-native bundle \
     --platform android \
     --dev false \
     --minify true \
     --entry-file index.js \
     --bundle-output dist/android-release/index.android.bundle \
     --sourcemap-output dist/android-release/index.android.bundle.map \
     --assets-dest dist/android-release/res
  ```
   The React Native CLI sets `**NODE_ENV**` from `**--dev false**` for this run. If uploads are still skipped, your shell may be forcing `**NODE_ENV=development**` earlier—prefix once with `**NODE_ENV=production**` or see `**FARO_SKIP_SOURCEMAP_UPLOAD**`. Use `**FARO_METRO_VERBOSE=1**` for `**[Faro]**` logs.
2. **Verify (Android):**
  - **Preamble / bundle id:** `head -n 5 dist/android-release/index.android.bundle` — should show the Faro prelude setting `**__faroBundleId_<appName>`** (see `sourcemaps.config.json` / `metro.config.js`) with a value matching `**bundleId**` in that file or `**FARO_BUNDLE_ID**` when set.
  - **Source map:** `dist/android-release/index.android.bundle.map` should be valid JSON with `**version`: 3** and a non-empty `**sources`** array. With default `metro.config.js` (no `**FARO_PLATFORM**` / `**FARO_SOURCEMAP_FILE**` override), the map’s top-level `**file**` should be `**index.android.bundle**` — matching `**releaseBundleFilename**` on Android in `**src/bootstrap.ts**`. Inspect in your editor, or validate JSON parses with:
    ```bash
    node -e 'const o=JSON.parse(require("fs").readFileSync("dist/android-release/index.android.bundle.map","utf8")); console.log("OK:", { version: o.version, file: o.file ?? "(omitted by Metro — optional)", sources: o.sources?.length });'
    ```
  - **Upload:** if uploads are not skipped, logs should show a request to your `**endpoint`** path `**…/app/<appId>/sourcemaps/<bundleId>**`. A `**2xx**` response confirms the API accepted the map; DNS or TLS errors against a placeholder host only mean the URL was built and the client tried to call it.

##### iOS

1. **Build:** use the same config as steps 1–2. Set `**FARO_PLATFORM=ios`** for this command so `**metro.config.js**` picks `**sourceMapFile`: `main.jsbundle**` (same basename as `**releaseBundleFilename**` on iOS in `**src/bootstrap.ts**`). Alternatively export `**FARO_SOURCEMAP_FILE=main.jsbundle**` instead of `**FARO_PLATFORM**`.
  ```bash
   mkdir -p dist/ios-release

   FARO_PLATFORM=ios npx react-native bundle \
     --platform ios \
     --dev false \
     --minify true \
     --entry-file index.js \
     --bundle-output dist/ios-release/main.jsbundle \
     --sourcemap-output dist/ios-release/main.jsbundle.map \
     --assets-dest dist/ios-release/assets
  ```
   The `**--platform ios**` flag selects the iOS graph; `**FARO_PLATFORM=ios**` only affects this repo’s Metro `**sourceMapFile**` default so the uploaded map’s `**file**` field aligns with Hermes stacks from an iOS release binary.
2. **Verify (iOS):** same expectations as Android, with iOS paths and basename `**main.jsbundle`**:
  - **Preamble / bundle id:** `head -n 5 dist/ios-release/main.jsbundle` — `**__faroBundleId_<appName>`** value must match `**bundleId**` / `**FARO_BUNDLE_ID**` (identical contract to Android).
  - **Source map:** `dist/ios-release/main.jsbundle.map` — valid JSON, `**version`: 3**, non-empty `**sources`**, top-level `**file**` should be `**main.jsbundle**` when `**FARO_PLATFORM=ios**` (or `**FARO_SOURCEMAP_FILE=main.jsbundle**`).
    ```bash
    node -e 'const o=JSON.parse(require("fs").readFileSync("dist/ios-release/main.jsbundle.map","utf8")); console.log("OK:", { version: o.version, file: o.file ?? "(omitted — optional)", sources: o.sources?.length });'
    ```
  - **Upload:** same as Android — `**[Faro]`** logs should show `**POST …/app/<appId>/sourcemaps/<bundleId>**` when uploads run; target `**2xx**` for a successful store.
  - **Runtime:** after §4 in the phase plan, confirm a device/stack payload shows `**meta.app.bundleId`** equal to this id and that JS errors symbolicate using the map uploaded for `**main.jsbundle**`.

`dist/` is gitignored. To skip uploads while still generating the bundle and map, set `**FARO_SKIP_SOURCEMAP_UPLOAD=1**` (or `true`).

### 3. iOS: Install CocoaPods

```bash
cd ios && pod install && cd ..
```

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

This app depends on `@grafana/faro-react-native` and `@grafana/faro-react-native-tracing` at **1.0.0-alpha.1** from npm (`package.json`; the git tag may be `v1.0.0-alpha.1`). After those versions are published, run `yarn install` here and commit the updated `yarn.lock` (with resolved URLs and integrity hashes). Until then, `yarn install` will 404 against the public registry.

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

