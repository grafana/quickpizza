GO_SOURCES=$(shell find . -type f -name '*.go' -not -path "./vendor/*")
FRONTEND_BUILD_DIR = pkg/web/build

# Builds frontend and backend Go code.
build:
	rm -rf $(FRONTEND_BUILD_DIR)
	export PUBLIC_BACKEND_ENDPOINT="" && \
	export PUBLIC_BACKEND_WS_ENDPOINT="" && \
	cd pkg/web && npm install && npm run build
	make build-go

# Does not (re)build frontend files, only Go code.
build-go:
	mkdir -p $(FRONTEND_BUILD_DIR)
	test -e $(FRONTEND_BUILD_DIR)/index.html || \
		cp pkg/web/dev.html $(FRONTEND_BUILD_DIR)/index.html
	go build -o bin/quickpizza ./cmd

.PHONY: proto
proto:
	protoc --go_out=. --go-grpc_out=. proto/quickpizza.proto

format:
	@goimports -w -l $(GO_SOURCES)

format-web:
	cd pkg/web/ && npm run format

format-check:
	@out=$$(goimports -l $(GO_SOURCES)) && echo "$$out" && test -z "$$out"

docker-build:
	docker build . -t grafana/quickpizza-local:latest

docker-run:
	docker run --rm -it -p 3333:3333 -p 3334:3334 -p 3335:3335 -v $$(pwd):/db -e QUICKPIZZA_DB=file:/db/quickpizza.db grafana/quickpizza-local:latest
