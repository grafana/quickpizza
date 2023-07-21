package main

import (
	"context"
	http "net/http"
	"os"
	"strconv"
	"time"

	"github.com/grafana/quickpizza/pkg/database"
	qphttp "github.com/grafana/quickpizza/pkg/http"
	"github.com/grafana/quickpizza/pkg/tracing"
	"github.com/hashicorp/go-retryablehttp"
	"go.opentelemetry.io/contrib/instrumentation/net/http/otelhttp"
	"go.opentelemetry.io/otel/propagation"
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

	// Create an HTTP client configured from env vars.
	// If no specific env vars are set, this will return a http client that does not perform any retries.
	httpCli := clientFromEnv()

	httpRequestTimeout := time.Duration(envInt("QUICKPIZZA_TIMEOUT_MS")) * time.Millisecond
	if httpRequestTimeout == 0 {
		httpRequestTimeout = 1000 * time.Millisecond
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
		catalogClient := qphttp.NewCatalogClient(envEndpoint("QUICKPIZZA_CATALOG")).WithClient(httpCli)
		copyClient := qphttp.NewCopyClient(envEndpoint("QUICKPIZZA_COPY")).WithClient(httpCli)

		server = server.WithRecommendations(catalogClient, copyClient)
	}

	listen := ":3333"
	globalLogger.Info("Starting QuickPizza", zap.String("listenAddress", listen))
	err = http.ListenAndServe(listen, server)
	if err != nil {
		globalLogger.Error("Running HTTP server", zap.Error(err))
	}
}

// clientFromEnv returns an *http.Client implementation according to the retries and backoff specified in env vars.
func clientFromEnv() *http.Client {
	// Configure an underlying client with otel transport.
	// Otel transport takes care of generating spans for outcoming requests, as well as propagating trace IDs on those
	// requests.
	httpClient := &http.Client{
		Transport: otelhttp.NewTransport(
			nil, // Default transport.
			// Propagator will retrieve the tracer used in the server from memory.
			otelhttp.WithPropagators(propagation.TraceContext{}),
		),
	}

	timeout := envDuration("QUICKPIZZA_TIMEOUT")
	if timeout == 0 {
		timeout = time.Second
	}

	httpClient.Timeout = timeout

	retriableClient := retryablehttp.NewClient()
	retriableClient.Logger = nil
	// Configure retryablehttp to use the instrumented client.
	// Retries occur at the retriableClient layer, so instrumentation will see failures from httpClient.
	retriableClient.HTTPClient = httpClient

	retriableClient.RetryMax = envInt("QUICKPIZZA_RETRIES")

	if retryMin := envDuration("QUICKPIZZA_BACKOFF_MIN"); retryMin != 0 {
		retriableClient.RetryWaitMin = retryMin
	}

	if retryMax := envDuration("QUICKPIZZA_BACKOFF_MAX"); retryMax != 0 {
		retriableClient.RetryWaitMax = retryMax
	}

	// Return a stdlib client that uses retryablehttp as transport.
	return retriableClient.StandardClient()
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

// envInt returns the 32-bit integer value for the specified env var, or 0 if it is not set or cannot be parsed.
func envInt(name string) int {
	v, found := os.LookupEnv(name)
	if !found {
		return 0
	}

	b, err := strconv.ParseInt(v, 10, 32)
	if err != nil {
		return 0
	}

	return int(b)
}

// envInt returns the time.Duration value for the specified env var, or 0 if it is not set or cannot be parsed.
func envDuration(name string) time.Duration {
	v, found := os.LookupEnv(name)
	if !found {
		return 0
	}

	d, err := time.ParseDuration(v)
	if err != nil {
		return 0
	}

	return d
}
