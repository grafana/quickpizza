package http

import (
	"context"
	"fmt"
	"net/http"
	"net/url"

	"github.com/go-chi/chi"
	"go.opentelemetry.io/contrib/instrumentation/net/http/otelhttp"
	"go.opentelemetry.io/otel/exporters/otlp/otlptrace"
	"go.opentelemetry.io/otel/exporters/otlp/otlptrace/otlptracegrpc"
	"go.opentelemetry.io/otel/exporters/otlp/otlptrace/otlptracehttp"
	"go.opentelemetry.io/otel/propagation"
	"go.opentelemetry.io/otel/sdk/resource"
	sdktrace "go.opentelemetry.io/otel/sdk/trace"
	semconv "go.opentelemetry.io/otel/semconv/v1.17.0"
)

// TraceInstaller installs tracing middleware into a chi router.
// An uninitialized TraceInstaller behaves like a noop, where calls to Install have no effect.
type TraceInstaller struct {
	insecure bool
	exporter *otlptrace.Exporter
}

// NewTraceInstaller creates a new initialized TraceInstaller that will set up traces and push them.
func NewTraceInstaller(ctx context.Context, endpointUrl string) (*TraceInstaller, error) {
	u, err := url.Parse(endpointUrl)
	if err != nil {
		return nil, fmt.Errorf("parsing endpoint url: %w", err)
	}

	var client otlptrace.Client
	switch u.Scheme {
	case "http":
		client = otlptracehttp.NewClient(otlptracehttp.WithInsecure(), otlptracehttp.WithEndpoint(u.Host))
	case "https":
		client = otlptracehttp.NewClient(otlptracehttp.WithEndpoint(u.Host))
	case "grpc":
		client = otlptracegrpc.NewClient(otlptracegrpc.WithEndpoint(u.Host))
	default:
		return nil, fmt.Errorf("unsupported protocol %q", u.Scheme)
	}

	exporter, err := otlptrace.New(ctx, client)
	if err != nil {
		return nil, fmt.Errorf("building otlp exporter: %w", err)
	}

	return &TraceInstaller{exporter: exporter}, nil
}

// Insecure instructs the TraceInstaller to trust incoming trace IDs.
func (t *TraceInstaller) Insecure() {
	t.insecure = true
}

// Install adds tracing middleware to the supplied chi.Router.
// extraOpts take precedence over the default opts.
func (t *TraceInstaller) Install(r chi.Router, serviceName string, extraOpts ...otelhttp.Option) {
	if t.exporter == nil {
		return
	}

	// We discard the error here as it cannot possibly take place with the parameters we use.
	res, _ := resource.Merge(
		resource.Default(),
		resource.NewWithAttributes(
			semconv.SchemaURL,
			semconv.ServiceName(serviceName),
		),
	)

	p := sdktrace.NewTracerProvider(
		sdktrace.WithBatcher(t.exporter),
		sdktrace.WithResource(res),
	)

	defaultOpts := []otelhttp.Option{
		otelhttp.WithTracerProvider(p),
		otelhttp.WithPropagators(propagation.TraceContext{}),
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
			serviceName,
			append(defaultOpts, extraOpts...)...,
		)
	})
}

func (t *TraceInstaller) isPublic(r *http.Request) bool {
	if t.insecure {
		return false // Nothing is considered public if insecureTracing is on.
	}

	if r.Header.Get("X-Is-Internal") != "" {
		return false // Internal header is set, request is not public.
	}

	return true
}
