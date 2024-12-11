GO_SOURCES=$(shell find . -type f -name '*.go' -not -path "./vendor/*")

# Note: does not include frontend files, only Go code.
.PHONY: build
build:
	go build -tags=mock -o bin/quickpizza ./cmd

.PHONY: proto
proto:
	protoc --go_out=. --go-grpc_out=. proto/quickpizza.proto

.PHONY: format
format:
	@goimports -w -l $(GO_SOURCES)

.PHONY: format-check
format-check:
	@out=$$(goimports -l $(GO_SOURCES)) && echo "$$out" && test -z "$$out"

.PHONY: docker-localdev-build
docker-localdev-build:
	docker build . -t grafana/quickpizza:localdev

.PHONY: docker-localdev-run
docker-localdev-run:
	docker run --rm -it -p 3333:3333 -p 3334:3334 -p 3335:3335 -v $$(pwd):/db -e QUICKPIZZA_DB=file:/db/quickpizza.db grafana/quickpizza:localdev
