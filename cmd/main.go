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

	// Enable services in this instance. Services are enabled with the following logic:
	// If QUICKPIZZA_ALL_SERVICES is either _not set_ or set to a truthy value, all services are enabled. This is the
	// default behavior.
	// If QUICKPIZZA_ALL_SERVICES is set to a falsy values, services are opted-in by setting the environment variables
	// below to a truty value.

	if envServe("QUICKPIZZA_FRONTEND") {
		server = server.WithFrontend()
	}

	// If we're deploying as microservices, the deployment serving the frontend should also serve the gateway, which
	// allows reaching public-facing endpoints from the outside.
	if envServe("QUICKPIZZA_FRONTEND") && !envServeAll() {
		server = server.WithGateway(
			envEndpoint("QUICKPIZZA_CATALOG"),
			envEndpoint("QUICKPIZZA_COPY"),
			envEndpoint("QUICKPIZZA_WS"),
			envEndpoint("QUICKPIZZA_RECOMMENDATIONS"),
		)
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

	// Recommendations service needs to know the URL where the Catalog and Copy services are located.
	// This URL is automatically set to `localhost` if Recommendations is enabled at the same time as either of those.
	// If they are not, URLs are sourced from QUICKPIZZA_CATALOG_ENDPOINT and QUICKPIZZA_COPY_ENDPOINT.
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

func envServeAll() bool {
	allSvcs, present := os.LookupEnv("QUICKPIZZA_ALL_SERVICES")
	allSvcsB, _ := strconv.ParseBool(allSvcs)

	// If QUICKPIZZA_ALL_SERVICES is not defined (default), serve everything.
	if !present {
		return true
	}

	// Otherwise, serve all if QUICKPIZZA_ALL_SERVICES is truthy.
	return allSvcsB
}

// envServe returns whether a service should be enabled.
func envServe(name string) bool {
	return envServeAll() || envBool(name)
}

// envEndpoint returns the endpoint for a given service. If the service is enabled in this instance, it returns
// `localhost`. If it isn't, it returns the value of QUICKPIZZA_SERVICENAME_ENDPOINT.fs
func envEndpoint(name string) string {
	if envServe(name) {
		return "http://localhost:3333"
	}

	endpoint, _ := os.LookupEnv(name + "_ENDPOINT")
	return endpoint
}

// envBool returns true if an env var is set and has a truthy value.
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
