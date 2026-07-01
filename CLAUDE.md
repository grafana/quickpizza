# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

QuickPizza is a demonstration web application that generates pizza recommendations. It's built with a Go backend and SvelteKit frontend, designed for k6 load testing workshops and observability demonstrations.

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
- `QUICKPIZZA_PUBLIC_API_TIMEOUT` - Wraps the public-api handler with `http.TimeoutHandler`; unset by default (no timeout). Returns **503** when the deadline fires. In monolith mode it covers the full request; in microservice mode it also covers the ReverseProxy leg to internal services. Uses Go duration format (e.g. `3s`).
- `QUICKPIZZA_RECOMMENDATIONS_HTTP_CLIENT_TIMEOUT` - Timeout on the HTTP client used by the recommendations service to call catalog and copy (default: `1s`). In monolith mode these are localhost calls; in microservice mode they are cross-service calls.
- `QUICKPIZZA_RECOMMENDATIONS_RETRIES` - Max retries for recommendations → catalog/copy calls (renamed from `QUICKPIZZA_RETRIES`).
- `QUICKPIZZA_RECOMMENDATIONS_BACKOFF_MIN` - Min backoff duration between retries (renamed from `QUICKPIZZA_BACKOFF_MIN`).
- `QUICKPIZZA_RECOMMENDATIONS_BACKOFF_MAX` - Max backoff duration between retries (renamed from `QUICKPIZZA_BACKOFF_MAX`).

## Development Notes

### Fault Injection
The application supports fault injection via HTTP headers and environment variables.

**HTTP headers** (per-request, via `pkg/errorinjector/`):
- `x-error-record-recommendation` - Trigger recommendation errors
- `x-error-get-ingredients` - Trigger ingredient retrieval errors
- `x-delay-record-recommendation` - Add delays to recommendations
- `x-delay-get-ingredients` - Add delays to ingredient retrieval
- Add `-percentage` suffix to any error header to control probability

**Environment variables** (process-wide, Go duration string, e.g. `500ms`, `2s`):
- `QUICKPIZZA_DELAY_RECOMMENDATIONS` - Delay all recommendations endpoints
- `QUICKPIZZA_DELAY_RECOMMENDATIONS_API_PIZZA_GET` - Delay `GET /api/pizza/{id}`
- `QUICKPIZZA_DELAY_RECOMMENDATIONS_API_PIZZA_POST` - Delay `POST /api/pizza` (pizza generation)
- `QUICKPIZZA_DELAY_COPY` - Delay all copy endpoints
- `QUICKPIZZA_DELAY_COPY_API_QUOTES` - Delay `GET /api/quotes`
- `QUICKPIZZA_DELAY_COPY_API_NAMES` - Delay pizza name generation
- `QUICKPIZZA_DELAY_COPY_API_ADJECTIVES` - Delay adjective generation
- `QUICKPIZZA_DELAY_FRONTEND_CSS_ASSETS` - Delay CSS asset serving
- `QUICKPIZZA_DELAY_FRONTEND_PNG_ASSETS` - Delay PNG asset serving
- `QUICKPIZZA_FAIL_RATE_RECOMMENDATIONS_API_PIZZA_POST` - Random failure rate (0-100) for `POST /api/pizza`

**Timeout testing example**: set `QUICKPIZZA_DELAY_RECOMMENDATIONS_API_PIZZA_POST=3s` with `QUICKPIZZA_PUBLIC_API_TIMEOUT=1s` to trigger 503 responses on pizza requests.

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
- k6 extensions and examples
- Prometheus output for k6 metrics correlation
