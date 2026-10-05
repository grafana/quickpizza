GO_SOURCES=$(shell find . -type f -name '*.go' -not -path "./vendor/*")
FRONTEND_BUILD_DIR = pkg/web/build

# Docker Compose auto-loads .env; make does not, so read it here too. Without
# this, overriding a port in .env would move the container but leave `make load`
# writing k6 results to whatever is on the default port instead.
-include .env

K6              ?= k6
QUICKPIZZA_PORT ?= 3333
PROMETHEUS_PORT ?= 9090
GRAFANA_PORT    ?= 3000
export QUICKPIZZA_PORT PROMETHEUS_PORT GRAFANA_PORT

BASE_URL ?= http://localhost:$(QUICKPIZZA_PORT)

# So that -o experimental-prometheus-rw follows PROMETHEUS_PORT instead of
# k6's hardcoded localhost:9090 default.
K6_PROMETHEUS_RW_SERVER_URL ?= http://localhost:$(PROMETHEUS_PORT)/api/v1/write
export K6_PROMETHEUS_RW_SERVER_URL
# Extra flags passed straight to `k6 run`, e.g.
#   make load K6_FLAGS="-o experimental-prometheus-rw"
#   make load K6_FLAGS="--out web-dashboard"
#   make load K6_FLAGS="--vus 50 --duration 1m"
K6_FLAGS ?=

# The "k6 Prometheus" dashboard filters every panel by a `testid` label, which k6
# only emits if we tag the run. Tagging per run also lets you compare runs in the
# dashboard's test-run dropdown.
STAMP  := $(shell date +%Y%m%d-%H%M%S)
K6_RUN  = $(K6) run $(K6_FLAGS) -e BASE_URL=$(BASE_URL)

## ----- Workshop -----

.PHONY: up
up: # Start QuickPizza, Postgres, Prometheus and Grafana
	docker compose up -d --wait
	@echo ""
	@echo "QuickPizza  http://localhost:$(QUICKPIZZA_PORT)"
	@echo "Grafana     http://localhost:$(GRAFANA_PORT)  (dashboard: k6 Prometheus)"
	@echo "Prometheus  http://localhost:$(PROMETHEUS_PORT)"

.PHONY: down
down: # Stop everything and remove the containers
	docker compose down

.PHONY: logs
logs: # Tail the QuickPizza logs
	docker compose logs -f quickpizza

.PHONY: smoke
smoke: # Run the smoke test (1 VU, 30s)
	$(K6_RUN) --tag testid=smoke-$(STAMP) k6/01-smoke.js

.PHONY: load
load: # Run the load test (ramp to 10 VUs, ~2m)
	$(K6_RUN) --tag testid=load-$(STAMP) k6/02-load.js

.PHONY: spike
spike: # Run the spike test (peak of 100 VUs, ~2m)
	$(K6_RUN) --tag testid=spike-$(STAMP) k6/03-spike.js

## ----- Application -----

.PHONY: build
build: build-web build-go # Build frontend and backend

.PHONY: build-web
build-web: # Build frontend assets
	rm -rf $(FRONTEND_BUILD_DIR)
	export PUBLIC_BACKEND_ENDPOINT="" && \
	export PUBLIC_BACKEND_WS_ENDPOINT="" && \
	cd pkg/web && npm install && npm run build

.PHONY: build-go
build-go: # Build Go binary (doesn't rebuild frontend)
	mkdir -p $(FRONTEND_BUILD_DIR)
	test -e $(FRONTEND_BUILD_DIR)/index.html || \
		cp pkg/web/dev.html $(FRONTEND_BUILD_DIR)/index.html
	go build -o bin/quickpizza ./cmd

.PHONY: install-web
install-web: # Install frontend dependencies
	cd pkg/web && npm install

.PHONY: dev
dev: # Run with live-reload (frontend dev server + backend with -dev flag)
	@echo "Starting dev server with live-reload"
	@trap 'kill 0' EXIT; \
	(export PUBLIC_BACKEND_ENDPOINT="http://localhost:3333" && \
	export PUBLIC_BACKEND_WS_ENDPOINT="ws://localhost:3333/ws" && \
	cd pkg/web && npm run dev) & \
	go run ./cmd -dev

.PHONY: docker-build
docker-build: # Build the QuickPizza image locally as local-quickpizza:latest
	docker build . -t local-quickpizza:latest

.PHONY: format
format: format-go format-web

.PHONY: format-go
format-go: # Format Go code with goimports
	@goimports -w -l $(GO_SOURCES)

.PHONY: format-web
format-web: # Format frontend code
	cd pkg/web/ && npm run biome-format

.PHONY: format-check
format-check: # Check Go code formatting
	@out=$$(goimports -l $(GO_SOURCES)) && echo "$$out" && test -z "$$out"

.PHONY: test-go
test-go: # Run Go unit tests
	go test ./... -count=1

.PHONY: help
help: # Show help for each of the Makefile recipes.
	@grep -E '^[a-zA-Z0-9 -]+:.*#'  Makefile | sort | while read -r l; do printf "\033[1;32m$$(echo $$l | cut -f 1 -d':')\033[00m:$$(echo $$l | cut -f 2- -d'#')\n"; done
