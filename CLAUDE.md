# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

QuickPizza is a demonstration web application that generates pizza recommendations. It's built with a Go backend and SvelteKit frontend, designed for k6 load testing workshops and observability demonstrations.

The repository also contains a **native iOS demo app** (`Mobiles/ios/`) that demonstrates mobile observability with OpenTelemetry. It connects to the QuickPizza backend and exports traces/logs over OTLP to a Grafana Cloud stack.

### iOS App Quick Reference
- **Location:** `Mobiles/ios/`
- **README:** `Mobiles/ios/README.md` — full setup instructions for running on a local simulator or BrowserStack
- **Start backend:** `docker run --rm -d -p 3333:3333 ghcr.io/grafana/quickpizza-local:latest`
- **Configure:** `cp Mobiles/ios/Config.xcconfig.example Mobiles/ios/Config.xcconfig` then fill in `OTLP_ENDPOINT` and `OTLP_AUTH_HEADER`
- **Run on simulator:** `bash Mobiles/ios/Scripts/sim-run.sh`
- **OTLP target stack:** `mobileo11y.grafana-dev.net`

## Key Commands

### Building & Running
- `make build` - Build frontend and backend together
- `make build-go` - Build only Go backend (doesn't rebuild frontend)
- `docker run --rm -it -p 3333:3333 ghcr.io/grafana/quickpizza-local:latest` - Run with Docker

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

Three native/cross-platform clients that demonstrate mobile observability against the QuickPizza backend.

### Android (`Mobiles/android/`)

- **Stack:** Kotlin, Jetpack Compose, Hilt, OkHttp, OpenTelemetry Android 1.2.0-alpha
- **Observability:** Manual spans (`auth.login`, `pizza.get_recommendation`, `pizza.rate`), auto OkHttp HTTP spans, structured logs via AppLogger, unhandled exception capture, 15-min session tracking
- **Config:** `app/src/main/res/raw/config.json` — `BASE_URL` (default `http://10.0.2.2:3333`), `OTLP_ENDPOINT`, `OTLP_AUTH_HEADER`
- **Build:** `JAVA_HOME=/home/domas/apps/android-studio/jbr ./gradlew assembleDebug` (system JDK too old; use Android Studio's bundled JDK)
- **Resource attrs:** `service.name=quickpizza-android`, `service.namespace=quickpizza`

### Flutter (`Mobiles/flutter/`)

- **Stack:** Flutter/Dart, Riverpod, GoRouter, Grafana Faro SDK 0.8.0
- **Observability:** Faro SDK for frontend telemetry (traces, logs, errors); cross-platform (Android, iOS, web)
- **Config:** `config.json` at project root — `BASE_URL`, `FARO_COLLECTOR_URL`
- **Build:** `flutter run --dart-define-from-file=config.json` or `./scripts/run-android.sh` / `./scripts/run-ios.sh`

### iOS (`Mobiles/ios/`)

- **Stack:** Swift, SwiftUI (iOS 17+), Swift Package Manager, OpenTelemetry Swift
- **Observability:** Manual spans + auto URLSession instrumentation, structured logs (OSLog + OTel), MetricKit crash/hang diagnostics, 15-min session tracking; in-app Debug tab for triggering test crashes
- **Config:** `Config.xcconfig` → auto-generates `BuildConfig.generated.swift` — `OTLP_ENDPOINT`, `OTLP_AUTH_HEADER`
- **Build:** Xcode (see `Mobiles/docs/XCODE_SETUP.md`)
- **Resource attrs:** `service.name=quickpizza-ios`, `service.namespace=quickpizza`

### Shared Observability Model

All apps emit traces (manual business spans + auto HTTP), structured logs, exception/crash records, and session IDs. Android/iOS export via OTLP HTTP; Flutter uses Faro collector. Docs in `Mobiles/docs/`.

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
