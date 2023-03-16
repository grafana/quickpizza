.PHONY: run
run:
	go generate web/web.go 
	go run .

.PHONY: build
build:
	go generate web/web.go 
	go build -o bin/quickpizza
