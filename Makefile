.PHONY: run
run:
	go generate pkg/web/web.go 
	GO111MODULE=on CGO_ENABLED=0 go run .

.PHONY: build
build:
	go generate pkg/web/web.go 
	GO111MODULE=on CGO_ENABLED=0 go build -o bin/quickpizza
