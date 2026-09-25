package http

import (
	"context"
	"fmt"
	"net/url"
	"os"
	"time"

	"github.com/go-chi/chi/v5"
	"go.opentelemetry.io/contrib/instrumentation/net/http/otelhttp"
	"go.opentelemetry.io/otel/attribute"
	"go.opentelemetry.io/otel/exporters/otlp/otlpmetric/otlpmetricgrpc"
	"go.opentelemetry.io/otel/exporters/otlp/otlpmetric/otlpmetrichttp"
	sdkmetric "go.opentelemetry.io/otel/sdk/metric"
	"go.opentelemetry.io/otel/sdk/resource"
	semconv "go.opentelemetry.io/otel/semconv/v1.17.0"
)

// OTelInstaller installs tracing middleware into a chi router.
// An uninitialized OTelInstaller behaves like a noop, where calls to Install have no effect.
//
// Install dispatches to one of two independent implementations depending on
// InstrumentationMode:
//   - installSDK (otel-sdk.go, the default): this app's own OTel Go SDK instruments itself.
//   - installOBI (otel-obi.go): an external OBI sidecar instruments this app via eBPF instead.
//
// See docs/otel.md for what each mode does and why they're kept in separate files.
type OTelInstaller struct {
	insecure  bool
	installed bool
	endpoint  *url.URL
}

// NewOTelInstaller creates a new OTelInstaller.
// Call Install to set up traces and metrics.
func NewOTelInstaller(ctx context.Context, endpointUrl string) (*OTelInstaller, error) {
	u, err := url.Parse(endpointUrl)
	if err != nil {
		return nil, fmt.Errorf("parsing endpoint url: %w", err)
	}

	return &OTelInstaller{endpoint: u}, nil
}

// Insecure instructs the OTelInstaller to trust incoming trace IDs.
func (t *OTelInstaller) Insecure() {
	t.insecure = true
}

// InstrumentationMode reports the value of QUICKPIZZA_OTEL_INSTRUMENTATION_MODE,
// defaulting to "sdk". See docs/otel.md for what each mode does. Exported because callers
// outside this package that build their own otelhttp-wrapped HTTP clients (e.g.
// cmd/main.go's recommendations→catalog/copy client) need to skip that wrapping too in
// "obi" mode, for the same reason installOBI skips otelhttp: OBI already captures that
// HTTP traffic via eBPF, so app-side otelhttp instrumentation would just duplicate it.
//
//   - "sdk" (default, otel-sdk.go): this app's own OTel Go SDK creates and exports every
//     span/metric, as it always has.
//   - "obi" (otel-obi.go): HTTP and business-logic traces (plus HTTP metrics) are left for
//     an external OBI (OpenTelemetry eBPF Instrumentation) sidecar to capture instead.
func InstrumentationMode() string {
	mode, ok := os.LookupEnv("QUICKPIZZA_OTEL_INSTRUMENTATION_MODE")
	if !ok || mode == "" {
		return "sdk"
	}
	return mode
}

// Install sets up tracing/metrics for the given chi.Router, using whichever implementation
// InstrumentationMode selects. extraOpts take precedence over installSDK's default otelhttp
// options; installOBI ignores them entirely, since it never runs otelhttp.
func (t *OTelInstaller) Install(r chi.Router, serviceComponent string, extraOpts ...otelhttp.Option) error {
	res := buildResource(serviceComponent)
	protocol := otlpExporterProtocol()

	if InstrumentationMode() == "obi" {
		return t.installOBI(r, res, protocol)
	}
	return t.installSDK(r, serviceComponent, res, protocol, extraOpts...)
}

// buildResource builds this service's OTel Resource attributes from QUICKPIZZA_OTEL_SERVICE_*
// env vars plus the given component name. Shared by both instrumentation modes.
func buildResource(serviceComponent string) *resource.Resource {
	// TODO: can leverage default OTEL_SERVICE_NAME, OTEL_RESOURCE_ATTRIBUTES env vars
	serviceName, ok := os.LookupEnv("QUICKPIZZA_OTEL_SERVICE_NAME")
	if !ok {
		serviceName = "quickpizza"
	}
	serviceNamespace, ok := os.LookupEnv("QUICKPIZZA_OTEL_SERVICE_NAMESPACE")
	if !ok {
		serviceNamespace = "quickpizza"
	}
	serviceInstanceID, ok := os.LookupEnv("QUICKPIZZA_OTEL_SERVICE_INSTANCE_ID")
	if !ok {
		serviceInstanceID = "local"
	}

	// We discard the error here as it cannot possibly take place with the parameters we use.
	res, _ := resource.Merge(
		resource.Default(),
		resource.NewWithAttributes(
			semconv.SchemaURL,
			semconv.ServiceName(serviceName),
			attribute.KeyValue{Key: "service.component", Value: attribute.StringValue(serviceComponent)},
			attribute.KeyValue{Key: "service.namespace", Value: attribute.StringValue(serviceNamespace)},
			attribute.KeyValue{Key: "service.instance.id", Value: attribute.StringValue(serviceInstanceID)},
		),
	)
	return res
}

// otlpExporterProtocol reports OTEL_EXPORTER_OTLP_PROTOCOL, defaulting to "http/protobuf".
// Shared by both instrumentation modes: installSDK uses it for its trace and metric
// exporters, installOBI for its metric exporter alone (OBI itself reads the same env var
// independently, for its own OTLP exporters, from its own container's environment).
func otlpExporterProtocol() string {
	protocol, ok := os.LookupEnv("OTEL_EXPORTER_OTLP_PROTOCOL")
	if !ok {
		protocol = "http/protobuf"
	}
	return protocol
}

// createMetricProvider builds an OTLP metric exporter/provider for the given endpoint.
// Shared by both instrumentation modes: even in "obi" mode, this app still needs a real
// MeterProvider for Go runtime metrics (goroutines, GC, ...), which OBI doesn't produce.
func createMetricProvider(ctx context.Context, endpoint *url.URL, otlpProtocol string, resource *resource.Resource) (*sdkmetric.MeterProvider, error) {
	if endpoint.Scheme != "http" && endpoint.Scheme != "https" {
		return nil, fmt.Errorf("unsupported scheme %q", endpoint.Scheme)
	}

	insecure := endpoint.Scheme == "http"

	var exporter sdkmetric.Exporter
	var err error

	switch otlpProtocol {
	case "grpc":
		if insecure {
			exporter, err = otlpmetricgrpc.New(ctx, otlpmetricgrpc.WithEndpoint(endpoint.Host), otlpmetricgrpc.WithInsecure())
		} else {
			exporter, err = otlpmetricgrpc.New(ctx, otlpmetricgrpc.WithEndpoint(endpoint.Host))
		}
	case "http/protobuf":
		if insecure {
			exporter, err = otlpmetrichttp.New(ctx, otlpmetrichttp.WithEndpoint(endpoint.Host), otlpmetrichttp.WithInsecure())
		} else {
			exporter, err = otlpmetrichttp.New(ctx, otlpmetrichttp.WithEndpoint(endpoint.Host))
		}
	default:
		return nil, fmt.Errorf("unsupported protocol %q", otlpProtocol)
	}

	if err != nil {
		return nil, fmt.Errorf("new otlp metric exporter failed: %w", err)
	}

	metricReader := sdkmetric.NewPeriodicReader(exporter, sdkmetric.WithInterval(5*time.Second))

	var p = sdkmetric.NewMeterProvider(
		sdkmetric.WithReader(metricReader),
		sdkmetric.WithResource(resource),
	)
	return p, nil
}
