package main

import (
	"context"
	http "net/http"
	"os"
	"strconv"

	qphttp "github.com/grafana/quickpizza/pkg/http"
	"github.com/grafana/quickpizza/pkg/tracing"
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

	if otlpEndpoint, _ := os.LookupEnv("OTLP_ENDPOINT"); otlpEndpoint != "" {
		ctx, cancel := context.WithCancel(context.Background())
		defer cancel()

		tp, err := tracing.OTLPProvider(ctx, otlpEndpoint)
		if err != nil {
			globalLogger.Fatal("Cannot create OTLP tracer", zap.Error(err))
		}

		server = server.WithTracing(tp)
	}

	// Always add prometheus middleware.
	server = server.WithPrometheus()

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

	listen := ":3333"
	globalLogger.Info("Starting QuickPizza", zap.String("listenAddress", listen))
	err = http.ListenAndServe(listen, server)
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
