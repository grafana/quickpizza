# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

QuickPizza is a demonstration web application that generates pizza recommendations. It's built with a Go backend and SvelteKit frontend, designed for k6 load testing workshops and observability demonstrations.

The repository also contains **four QuickPizza mobile demo apps** under `Mobiles/` that demonstrate mobile observability against the same backend. The four apps share screens and workflows but use different SDKs:

- `Mobiles/flutter/` and `Mobiles/react-native/` use the Grafana **Faro** SDKs and export to Grafana Cloud Frontend Observability.
- `Mobiles/ios/` and `Mobiles/android/` use **OpenTelemetry** mobile SDKs and export over OTLP/HTTP to Grafana Cloud Tempo + Loki (visualised via the "Android & iOS OTel RUM" custom dashboard).

For a single source of truth on what each app emits, where it lands, and how the SDKs differ, see [`Mobiles/docs/MOBILE_OBSERVABILITY_OVERVIEW.md`](./Mobiles/docs/MOBILE_OBSERVABILITY_OVERVIEW.md).

### Mobile Apps Quick Reference

- **Demo cloud stack:** internal Grafana Cloud stack — substitute your own (`<your-grafana-cloud-stack>.grafana.net`) when running outside Grafana Labs
- **Backend (local, mobile):** `docker run --rm -d -p 3333:3333 ghcr.io/grafana/quickpizza-mobile-local:latest` (or `QUICKPIZZA_IMAGE=ghcr.io/grafana/quickpizza-mobile-local:latest` with compose; k6/upstream uses `quickpizza-local`)
- **Shared feature spec:** [`Mobiles/FEATURES.md`](./Mobiles/FEATURES.md)
- **Per-platform READMEs:** [`Mobiles/flutter/README.md`](./Mobiles/flutter/README.md), [`Mobiles/react-native/README.md`](./Mobiles/react-native/README.md), [`Mobiles/ios/README.md`](./Mobiles/ios/README.md), [`Mobiles/android/README.md`](./Mobiles/android/README.md)
- **OTel mobile SDK gaps & contribution backlog:** [`Mobiles/docs/OTEL_MOBILE_MATURITY.md`](./Mobiles/docs/OTEL_MOBILE_MATURITY.md)
- **iOS native run:** `cp Mobiles/ios/Config.xcconfig.example Mobiles/ios/Config.xcconfig` (fill in OTLP creds), then `bash Mobiles/ios/Scripts/sim-run.sh`
- **Android native run:** `cp Mobiles/android/app/src/main/res/raw/config.json.example Mobiles/android/app/src/main/res/raw/config.json` (fill in OTLP creds), then `cd Mobiles/android && ./gradlew installDebug`

## Key Commands

### Building & Running
- `make build` - Build frontend and backend together
- `make build-go` - Build only Go backend (doesn't rebuild frontend)
- `docker run --rm -it -p 3333:3333 ghcr.io/grafana/quickpizza-mobile-local:latest` - Run backend for mobile (see root README `QUICKPIZZA_IMAGE`)

### Frontend Development
- `cd pkg/web && npm install` - Install frontend dependencies
- `cd pkg/web && npm run dev` - Start development server
- `cd pkg/web && npm run build` - Build production frontend
- `cd pkg/web && npm run biome-check` - Check frontend code
- `cd pkg/web && npm run biome-format` - Format frontend code

### Go Development
- `make format` - Format Go code with goimports
- `make format-check` - Check Go formatting
- `make proto` - Generate protobuf files from proto/quickpizza.proto

### Testing
- `./k6/run-tests.sh` - Run k6 tests (requires k6 installed)
- `./k6/run-tests.sh -u http://localhost:3333 -t "k6/foundations/*.js"` - Run specific tests
- All k6 tests are in the `k6/` directory organized by category

### Docker Development
- `make docker-build` - Build local Docker image
- `make docker-run` - Run local container with volume mounts

## Architecture

### Microservices Architecture
The application is designed as a modular monolith that can be deployed as separate microservices. Services are controlled by environment variables:

- **PublicAPI** (`QUICKPIZZA_ENABLE_PUBLIC_API_SERVICE`) - Serves Frontend and Gateway
- **Frontend** -  Serves SvelteKit UI
- **Gateway** - Routes requests between services in microservice deployments
- **Catalog** (`QUICKPIZZA_ENABLE_CATALOG_SERVICE`) - Manages ingredients, tools, doughs, users, ratings
- **Copy** (`QUICKPIZZA_ENABLE_COPY_SERVICE`) - Handles quotes, names, adjectives for pizza generation
- **Recommendations** (`QUICKPIZZA_ENABLE_RECOMMENDATIONS_SERVICE`) - Core pizza recommendation logic
- **WebSocket** (`QUICKPIZZA_ENABLE_WS_SERVICE`) - Real-time communication
- **gRPC** (`QUICKPIZZA_ENABLE_GRPC_SERVICE`) - gRPC service on ports 3334/3335
- **Config** (`QUICKPIZZA_ENABLE_CONFIG_SERVICE`) - Configuration endpoint
- **HTTP Testing** (`QUICKPIZZA_ENABLE_HTTP_TESTING_SERVICE`) - HTTP testing utilities
- **Test K6 IO** (`QUICKPIZZA_ENABLE_TEST_K6_IO_SERVICE`) - Legacy test.k6.io replacement endpoints

### Key Packages
- `pkg/http/` - Main HTTP server and route handlers
- `pkg/database/` - Database abstraction (supports SQLite and PostgreSQL)
- `pkg/grpc/` - gRPC server implementation
- `pkg/web/` - SvelteKit frontend embedded in Go binary
- `pkg/model/` - Data models (Pizza, User, Ingredient, etc.)
- `pkg/errorinjector/` - Error injection for testing via headers

### Database
- Default: In-memory SQLite (`file::memory:?cache=shared`)
- Configurable via `QUICKPIZZA_DB` environment variable
- Supports PostgreSQL with `postgres://` connection strings
- Uses Bun ORM with migrations in `pkg/database/migrations/`

### Observability
Comprehensive observability built-in:
- **Tracing**: OpenTelemetry with configurable OTLP endpoint
- **Metrics**: Prometheus metrics on `/metrics` endpoint
- **Logging**: Structured JSON logging with slog
- **Profiling**: Pyroscope integration for continuous profiling
- **Frontend Observability**: Grafana Faro support

### Environment Configuration
- `QUICKPIZZA_ENABLE_ALL_SERVICES` - Enable all services (default: true)
- `QUICKPIZZA_LOG_LEVEL` - Set logging level (default: info)
- `QUICKPIZZA_OTLP_ENDPOINT` - OpenTelemetry collector endpoint
- `QUICKPIZZA_PYROSCOPE_ENDPOINT` - Pyroscope server for profiling
- `QUICKPIZZA_DB` - Database connection string

## Mobile Apps (`Mobiles/`)

Four QuickPizza clients that demonstrate mobile observability against the
same backend. They share screens, workflows, and a cross-platform Debug
tab, but use different telemetry SDKs.

For a deep, gcx-verified, side-by-side breakdown of what each app emits,
read [`Mobiles/docs/MOBILE_OBSERVABILITY_OVERVIEW.md`](./Mobiles/docs/MOBILE_OBSERVABILITY_OVERVIEW.md).

### Flutter (`Mobiles/flutter/`)

- **Stack:** Flutter/Dart, Riverpod, GoRouter, `faro` Dart SDK (`faro-mobile-flutter` 0.14.0).
- **Observability:** Faro emits `event` / `log` / `measurement` / `exception` signals; auto HTTP via `faro.tracing.fetch`; auto perf measurements (`app_memory`, `app_cpu_usage`, frame rates, `app_startup`); native crashes via custom `MethodChannel`-backed `NativeCrashService`.
- **Where it lands:** Frontend Observability plugin (Faro app `QuickPizza_Flutter`, id `69`). SDK is configured to send `app_name=QuickPizza_Flutter` to match the registry; older telemetry may still carry the legacy `quickpizza-flutter` kebab-case name.
- **Config:** `config.json` at project root — `BASE_URL`, `FARO_COLLECTOR_URL`.
- **Build:** `flutter run --dart-define-from-file=config.json` or `./scripts/run-android.sh` / `./scripts/run-ios.sh`.

### React Native (`Mobiles/react-native/`)

- **Stack:** React Native 0.84.x, `@grafana/faro-react-native` 1.0.0-alpha.1, `faro-react-native` 2.3.1.
- **Observability:** Faro signals as above, plus dual fetch + XMLHttpRequest auto tracing (`faro.tracing.fetch` + `faro.tracing.xml-http-request`), custom business measurements (`pizza.recommendation`, `pizza.rating`), native crash capture via Faro CrashKit (`type=crash`).
- **Where it lands:** Frontend Observability plugin (Faro app `QuickPizza_ReactNative`, id `123`).
- **Config:** `config.json` at `Mobiles/react-native/` — `BASE_URL`, `FARO_COLLECTOR_URL`.
- **Build:** `yarn ios` / `yarn android`.

### iOS native (`Mobiles/ios/`)

- **Stack:** Swift, SwiftUI (iOS 17+), Swift Package Manager, `opentelemetry-swift` 2.3.0.
- **Observability:** Manual spans (`pizza.get_recommendation`, `auth.login`, `pizza.rate`), auto HTTP via `URLSessionInstrumentation`, sessions via the `Sessions` library (15-min inactivity, `session.id` + `session.previous_id` on every signal), MetricKit crash/hang/CPU/disk-write diagnostics via `MetricKitInstrumentation` (delivered as logs + `MXMetricPayload` spans), manual `app.screen.view` events, OSLog + OTel dual logging.
- **Where it lands:** OTLP/HTTP → Grafana Cloud Tempo + Loki, visualised via the "Android & iOS OTel RUM" dashboard (and an iOS-specific dashboard) on the configured Grafana Cloud stack.
- **Config:** `Config.xcconfig` → auto-generates `BuildConfig.generated.swift` — `OTLP_ENDPOINT`, `OTLP_INSTANCE_ID`, `OTLP_API_KEY`. Runtime overrides via in-app Debug → Config.
- **Build:** Xcode or `bash Mobiles/ios/Scripts/sim-run.sh`.
- **Resource attrs:** `service.name=quickpizza-ios`, `service.namespace=quickpizza`, `service.version`, `service.build`, `deployment.environment`, `device.id`, `device.model.identifier`, `os.*`, `session.id`, `session.previous_id`, `telemetry.sdk.{language=swift, version=2.3.0}`.

### Android native (`Mobiles/android/`)

- **Stack:** Kotlin, Jetpack Compose, Hilt, OkHttp, `opentelemetry-android` 1.2.0-alpha (the OTel-Android **RUM agent**).
- **Observability:** Manual spans (`pizza.get_recommendation`, `auth.login`, `pizza.rate`), auto OkHttp HTTP spans, auto lifecycle spans (`AppStart`, `Paused`, `Stopped`), auto `screen.view` / `app.jank` events, auto `device.crash` (next launch) and `device.anr` (runtime) events, 15-min session tracking, OTLP disk buffering for offline resilience (toggleable via Debug screen).
- **Where it lands:** OTLP/HTTP → Grafana Cloud Tempo + Loki, visualised via the "Android & iOS OTel RUM" dashboard.
- **Config:** `app/src/main/res/raw/config.json` — `BASE_URL` (default `http://10.0.2.2:3333` on emulators), `OTLP_ENDPOINT`, `OTLP_INSTANCE_ID`, `OTLP_API_KEY`. Runtime overrides via in-app Debug → Config.
- **Build:** Android Studio or `cd Mobiles/android && ./gradlew installDebug`. Use Android Studio's bundled JDK (system JDK is often too old).
- **Resource attrs:** `service.name=quickpizza-android`, `service.namespace=quickpizza`, `service.version`, `deployment.environment`, `android.os.api_level`, `device.manufacturer`, `device.model.{identifier,name}`, `network.connection.type`, `app.installation.id`, `nav.{destination, previous_destination, kind}`, `telemetry.sdk.{language=java, version=1.2.0-alpha}`.

### Shared Debug screen

All four apps now expose an in-app **Debug** tab (Compose / SwiftUI / Flutter widgets / RN) for runtime config overrides, backend error/latency injection, client-side fault simulation, and triggering test logs / handled exceptions / native crashes. Code lives at `features/debug/` in each app. Android additionally exposes a `Disable disk buffering` toggle and an ANR card; iOS calls out the MetricKit delivery delay.

## Development Notes

### Error Injection
The application supports error injection via HTTP headers for testing:
- `x-error-record-recommendation` - Trigger recommendation errors
- `x-error-get-ingredients` - Trigger ingredient retrieval errors
- `x-delay-record-recommendation` - Add delays to recommendations
- `x-delay-get-ingredients` - Add delays to ingredient retrieval
- Add `-percentage` suffix to any error header to control probability

### Frontend Integration
- Frontend is built with SvelteKit and embedded in the Go binary
- Uses Vite for development builds
- Supports Grafana Faro for frontend observability
- WebSocket integration for real-time updates

### Authentication
- Token-based authentication with user management
- Admin endpoints with separate admin authentication
- CSRF protection for cookie-based authentication
- Authentication middleware can be bypassed with `X-Is-Internal` header

### Testing with k6
The application is specifically designed for k6 load testing:
- Extensive k6 test suite in `k6/` directory
- Support for k6 browser testing
- k6 extensions and disruptor examples
- Prometheus output for k6 metrics correlation
