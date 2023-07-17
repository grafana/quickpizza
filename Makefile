.PHONY: run
run:
	go generate pkg/web/web.go 
	GO111MODULE=on CGO_ENABLED=0 go run ./cmd

.PHONY: build
build:
	# TODO: add build recipe for npm
	go generate pkg/web/web.go
	GO111MODULE=on CGO_ENABLED=0 go build -o bin/quickpizza ./cmd
