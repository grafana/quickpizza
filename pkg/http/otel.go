package http

import (
	"context"
	"fmt"
	"log/slog"
	"net/http"
	"net/url"
	"os"
	"time"

	"github.com/go-chi/chi/v5"
	"github.com/go-chi/httplog/v2"
	otelpyroscope "github.com/grafana/otel-profiling-go"
	"go.opentelemetry.io/contrib/instrumentation/net/http/otelhttp"
	"go.opentelemetry.io/contrib/instrumentation/runtime"
	"go.opentelemetry.io/contrib/processors/baggagecopy"
	"go.opentelemetry.io/otel"
	"go.opentelemetry.io/otel/attribute"
	"go.opentelemetry.io/otel/baggage"
	"go.opentelemetry.io/otel/exporters/otlp/otlpmetric/otlpmetricgrpc"
	"go.opentelemetry.io/otel/exporters/otlp/otlpmetric/otlpmetrichttp"
	"go.opentelemetry.io/otel/exporters/otlp/otlptrace"
	"go.opentelemetry.io/otel/exporters/otlp/otlptrace/otlptracegrpc"
	"go.opentelemetry.io/otel/exporters/otlp/otlptrace/otlptracehttp"
	"go.opentelemetry.io/otel/propagation"
	sdkmetric "go.opentelemetry.io/otel/sdk/metric"
	"go.opentelemetry.io/otel/sdk/resource"
	sdktrace "go.opentelemetry.io/otel/sdk/trace"
	semconv "go.opentelemetry.io/otel/semconv/v1.17.0"
	"go.opentelemetry.io/otel/trace"
)

func LogTraceID(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		span := trace.SpanFromContext(r.Context())
		if span.SpanContext().HasTraceID() {
			traceID := span.SpanContext().TraceID().String()
			httplog.LogEntrySetField(r.Context(), "traceID", slog.StringValue(traceID))
		}
		next.ServeHTTP(w, r.WithContext(r.Context()))
	})
}

// OTelInstaller installs tracing middleware into a chi router.
// An uninitialized OTelInstaller behaves like a noop, where calls to Install have no effect.
type OTelInstaller struct {
	insecure  bool
	installed bool
	endpoint  *url.URL
}

func createTraceProvider(ctx context.Context, endpoint *url.URL, otlpProtocol string, resource *resource.Resource) (trace.TracerProvider, error) {
	var trace_client otlptrace.Client

	if endpoint.Scheme != "http" && endpoint.Scheme != "https" {
		return nil, fmt.Errorf("unsupported scheme %q", endpoint.Scheme)
	}

	insecure := endpoint.Scheme == "http"

	// Create client based on protocol
	switch otlpProtocol {
	case "grpc":
		if insecure {
			trace_client = otlptracegrpc.NewClient(
				otlptracegrpc.WithEndpoint(endpoint.Host),
				otlptracegrpc.WithInsecure(),
			)
		} else {
			trace_client = otlptracegrpc.NewClient(
				otlptracegrpc.WithEndpoint(endpoint.Host),
			)
		}
	case "http/protobuf":
		if insecure {
			trace_client = otlptracehttp.NewClient(
				otlptracehttp.WithEndpoint(endpoint.Host),
				otlptracehttp.WithInsecure(),
			)
		} else {
			trace_client = otlptracehttp.NewClient(
				otlptracehttp.WithEndpoint(endpoint.Host),
			)
		}
	default:
		return nil, fmt.Errorf("unsupported protocol %q", otlpProtocol)
	}
	trace_exporter, err := otlptrace.New(ctx, trace_client)
	if err != nil {
		return nil, fmt.Errorf("building otlp exporter: %w", err)
	}

	p := sdktrace.NewTracerProvider(
		sdktrace.WithSpanProcessor(
			baggagecopy.NewSpanProcessor(
				func(m baggage.Member) bool {
					return true // Accept all baggage members
				},
			),
		),
		sdktrace.WithBatcher(trace_exporter),
		sdktrace.WithResource(resource),
	)

	return p, nil
}

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

// Install OTel,
// - sets global OTel tracer and meter providers when called first time
// - enable runtime metrics only once
// - enable HTTP tracing and metrics on the supplied chi.Router
// extraOpts take precedence over the default opts
func (t *OTelInstaller) Install(r chi.Router, serviceComponent string, extraOpts ...otelhttp.Option) error {

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

	protocol, ok := os.LookupEnv("OTEL_EXPORTER_OTLP_PROTOCOL")
	if !ok {
		protocol = "http/protobuf"
	}

	ctx := context.Background()
	var tp trace.TracerProvider
	var mp *sdkmetric.MeterProvider
	var err error

	if t.endpoint == nil {
		// If endpoint is nil, use no-op providers (local tracing only)
		tp = sdktrace.NewTracerProvider()
		mp = sdkmetric.NewMeterProvider()
	} else {
		// Create providers that export to the configured endpoint
		tp, err = createTraceProvider(ctx, t.endpoint, protocol, res)
		if err != nil {
			return fmt.Errorf("creating trace provider: %w", err)
		}

		mp, err = createMetricProvider(ctx, t.endpoint, protocol, res)
		if err != nil {
			return fmt.Errorf("creating metric provider: %w", err)
		}
	}

	if !t.installed {
		// Set global providers only once
		// TODO: it's not great since we set first component to be called to be global.
		otel.SetTracerProvider(otelpyroscope.NewTracerProvider(tp))
		otel.SetTextMapPropagator(propagation.NewCompositeTextMapPropagator(propagation.TraceContext{}, propagation.Baggage{}))
		otel.SetMeterProvider(mp)

		// also start runtime instrumentation only once
		err = runtime.Start(
			runtime.WithMeterProvider(mp),
			runtime.WithMinimumReadMemStatsInterval(time.Second))
		if err != nil {
			return fmt.Errorf("starting runtime instrumentation: %w", err)
		}

		t.installed = true
	}

	defaultOpts := []otelhttp.Option{
		otelhttp.WithTracerProvider(otelpyroscope.NewTracerProvider(tp)),
		otelhttp.WithMeterProvider(mp),
		otelhttp.WithPropagators(otel.GetTextMapPropagator()),
		otelhttp.WithPublicEndpointFn(t.isPublic),
		// Use a name formatter that follows the semantic conventions for server-side span naming:
		// https://opentelemetry.io/docs/specs/otel/trace/semantic_conventions/http/#name
		otelhttp.WithSpanNameFormatter(func(_ string, r *http.Request) string {
			return fmt.Sprintf("%s %s", r.Method, r.URL.Path)
		}),
	}

	r.Use(func(handler http.Handler) http.Handler {
		return otelhttp.NewHandler(
			handler,
			serviceComponent,
			append(defaultOpts, extraOpts...)...,
		)
	})
	r.Use(LogTraceID)

	// Mark as installed after successful installation
	t.installed = true
	return nil
}

func (t *OTelInstaller) isPublic(r *http.Request) bool {
	if t.insecure {
		return false // Nothing is considered public if insecureTracing is on.
	}

	if r.Header.Get("X-Is-Internal") != "" {
		return false // Internal header is set, request is not public.
	}

	return true
}
