package main

import (
	http "net/http"
	"os"
	"strconv"

	qphttp "github.com/grafana/quickpizza/pkg/http"
	"go.uber.org/zap"
)

func main() {
	globalLogger, err := zap.NewProduction()
	if err != nil {
		panic(err)
	}

	server, err := qphttp.NewServer(globalLogger)
	if err != nil {
		globalLogger.Fatal("Cannot create server", zap.Error(err))
	}

	if envServe("QUICKPIZZA_FRONTEND") {
		server = server.WithFrontend()
	}

	if envServe("QUICKPIZZA_WS") {
		server = server.WithWS()
	}

	// TODO: Split this further in subsequent PRs.
	if envServe("QUICKPIZZA_API") {
		server = server.WithAPI()
	}

	globalLogger.Info("Starting QuickPizza. Listening on :3333")
	err = http.ListenAndServe(":3333", server)
	if err != nil {
		globalLogger.Error("Running HTTP server", zap.Error(err))
	}
}

func envServe(name string) bool {
	return envBool("QUICKPIZZA_ALL_SERVICES") || envBool(name)
}

func envBool(name string) bool {
	v, found := os.LookupEnv(name)
	if !found {
		return false
	}

	b, err := strconv.ParseBool(v)
	if err != nil {
		return false
	}

	return b
}
