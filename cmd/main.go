package main

import (
	"context"
	http "net/http"
	"os"
	"strconv"

	"github.com/grafana/quickpizza/pkg/database"
	qphttp "github.com/grafana/quickpizza/pkg/http"
	"github.com/grafana/quickpizza/pkg/tracing"
	"go.uber.org/zap"
)

func main() {
	globalLogger, err := zap.NewProduction()
	if err != nil {
		panic(err)
	}

	db := &database.InMemoryDatabase{}
	err = db.PopulateFromFile("data.json")
	if err != nil {
		globalLogger.Fatal("loading data from disk", zap.Error(err))
	}

	server, err := qphttp.NewServer(globalLogger)
	if err != nil {
		globalLogger.Fatal("Cannot create server", zap.Error(err))
	}

	if otlpEndpoint, _ := os.LookupEnv("QUICKPIZZA_OTLP_ENDPOINT"); otlpEndpoint != "" {
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

	if envServe("QUICKPIZZA_CATALOG") {
		server = server.WithCatalog(db)
	}

	if envServe("QUICKPIZZA_COPY") {
		server = server.WithCopy(db)
	}

	if envServe("QUICKPIZZA_RECOMMENDATIONS") {
		server = server.WithRecommendations(
			envEndpoint("QUICKPIZZA_CATALOG"),
			envEndpoint("QUICKPIZZA_COPY"),
		)
	}

	listen := ":3333"
	globalLogger.Info("Starting QuickPizza", zap.String("listenAddress", listen))
	err = http.ListenAndServe(listen, server)
	if err != nil {
		globalLogger.Error("Running HTTP server", zap.Error(err))
	}
}

func envServe(name string) bool {
	allSvcs, present := os.LookupEnv("QUICKPIZZA_ALL_SERVICES")
	allSvcsB, _ := strconv.ParseBool(allSvcs)

	// If QUICKPIZZA_ALL_SERVICES is not defined (default), serve everything.
	if !present {
		return true
	}

	// Otherwise, serve this service if explicitly enabled or if QUICKPIZZA_ALL_SERVICES == 1.
	return allSvcsB || envBool(name)
}

func envEndpoint(name string) string {
	if envServe(name) {
		return "http://localhost:3333"
	}

	endpoint, _ := os.LookupEnv(name + "_ENDPOINT")
	return endpoint
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
