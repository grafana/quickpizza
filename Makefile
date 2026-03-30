GO_SOURCES=$(shell find . -type f -name '*.go' -not -path "./vendor/*")
FRONTEND_BUILD_DIR = pkg/web/build

.PHONY: build
build: build-web build-go # Builds frontend and backend

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

.PHONY: proto
proto: # Generate protobuf files
	protoc --go_out=. --go-grpc_out=. proto/quickpizza.proto

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

.PHONY: docker-build
docker-build: # Build Docker image
	docker build . -t grafana/quickpizza-local:latest

.PHONY: docker-run
docker-run: # Run Docker container
	docker run --rm -it -p 3333:3333 -p 3334:3334 -p 3335:3335 -v $$(pwd):/db -e QUICKPIZZA_DB=file:/db/quickpizza.db grafana/quickpizza-local:latest

.PHONY: help
help: # Show help for each of the Makefile recipes.
	@grep -E '^[a-zA-Z0-9 -]+:.*#'  Makefile | sort | while read -r l; do printf "\033[1;32m$$(echo $$l | cut -f 1 -d':')\033[00m:$$(echo $$l | cut -f 2- -d'#')\n"; done

