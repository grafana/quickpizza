.PHONY: run
run:
	go generate pkg/web/web.go
	CGO_ENABLED=0 go run ./cmd

# TODO: add build recipe for npm
.PHONY: build
build:
	go generate pkg/web/web.go
	CGO_ENABLED=0 go build -o bin/quickpizza ./cmd
