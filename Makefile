GO_SOURCES=$(shell find . -type f -name '*.go' -not -path "./vendor/*")

.PHONY: run
run:
	go generate pkg/web/web.go
	CGO_ENABLED=0 go run ./cmd

# TODO: add build recipe for npm
.PHONY: build
build:
	go generate pkg/web/web.go
	CGO_ENABLED=0 go build -o bin/quickpizza ./cmd

.PHONY: proto
proto:
	protoc --go_out=. --go-grpc_out=. proto/quickpizza.proto

.PHONY: format
format:
	@goimports -w -l $(GO_SOURCES)

.PHONY: format-check
format-check:
	@out=$$(goimports -l $(GO_SOURCES)) && echo "$$out" && test -z "$$out"
