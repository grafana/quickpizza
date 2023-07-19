package main

import (
	"context"
	"net/http"
	"os"

	"github.com/grafana/quickpizza/pkg/config"
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

	// Create InMemoryDatabase. This database is used by the Catalog and Copy services.
	db := &database.InMemoryDatabase{}
	err = db.PopulateFromFile("data.json")
	if err != nil {
		globalLogger.Fatal("loading data from disk", zap.Error(err))
	}

	server, err := qphttp.NewServer(globalLogger)
	if err != nil {
		globalLogger.Fatal("Cannot create server", zap.Error(err))
	}

	// If QUICKPIZZA_OTLP_ENDPOINT is set, set up tracing outputting to it.
	// If it is not set, no tracing will be performed.
	if otlpEndpoint, _ := os.LookupEnv("QUICKPIZZA_OTLP_ENDPOINT"); otlpEndpoint != "" {
		serviceName, _ := os.LookupEnv("QUICKPIZZA_OTLP_SERVICE_NAME")
		if serviceName == "" {
			serviceName = "QuickPizza"
		}

		ctx, cancel := context.WithCancel(context.Background())
		defer cancel()

		tp, err := tracing.OTLPProvider(ctx, otlpEndpoint, serviceName)
		if err != nil {
			globalLogger.Fatal("Cannot create OTLP tracer", zap.Error(err))
		}

		server = server.WithTracing(tp)
	}

	// Always add prometheus middleware.
	server = server.WithPrometheus()

	runtimeConfig := config.Runtime{}

	// Enable services in this instance. Services are enabled with the following logic:
	// If QUICKPIZZA_ALL_SERVICES is either _not set_ or set to a truthy value, all services are enabled. This is the
	// default behavior.
	// If QUICKPIZZA_ALL_SERVICES is set to a falsy values, services are opted-in by setting the environment variables
	// below to a truty value.

	if runtimeConfig.Serve(config.ENV_SERVICE_FRONTEND) {
		server = server.WithFrontend()
	}

	// If we're deploying as microservices, the deployment serving the frontend should also serve the gateway, which
	// allows reaching public-facing endpoints from the outside.
	if runtimeConfig.Serve(config.ENV_SERVICE_FRONTEND) && !runtimeConfig.ServeAll() {
		server = server.WithGateway(
			runtimeConfig.Endpoint(config.ENV_SERVICE_CATALOG),
			runtimeConfig.Endpoint(config.ENV_SERVICE_COPY),
			runtimeConfig.Endpoint(config.ENV_SERVICE_WS),
			runtimeConfig.Endpoint(config.ENV_SERVICE_RECOMMENDATIONS),
		)
	}

	if runtimeConfig.Serve(config.ENV_SERVICE_WS) {
		server = server.WithWS()
	}

	if runtimeConfig.Serve(config.ENV_SERVICE_CATALOG) {
		server = server.WithCatalog(db)
	}

	if runtimeConfig.Serve(config.ENV_SERVICE_COPY) {
		server = server.WithCopy(db)
	}

	// Recommendations service needs to know the URL where the Catalog and Copy services are located.
	// config.Runtime will supply db-backed clients to the
	if runtimeConfig.Serve(config.ENV_SERVICE_RECOMMENDATIONS) {
		server = server.WithRecommendations(
			runtimeConfig.CatalogClient(db),
			runtimeConfig.CopyClient(db),
		)
	}

	listen := ":3333"
	globalLogger.Info("Starting QuickPizza", zap.String("listenAddress", listen))
	err = http.ListenAndServe(listen, server)
	if err != nil {
		globalLogger.Error("Running HTTP server", zap.Error(err))
	}
}
