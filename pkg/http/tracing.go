package http

import (
	"fmt"
	"net/http"

	"github.com/go-chi/chi"
	qpotel "github.com/grafana/quickpizza/pkg/otel"
	"go.opentelemetry.io/contrib/instrumentation/net/http/otelhttp"
	"go.opentelemetry.io/otel/sdk/resource"
	semconv "go.opentelemetry.io/otel/semconv/v1.17.0"
)

// TraceInstaller installs tracing middleware into a chi router.
// An uninitialized TraceInstaller behaves like a noop, where calls to Install have no effect.
type TraceInstaller struct {
	insecure bool
	prov     *qpotel.Provider
}

// NewTraceInstaller creates a new initialized TraceInstaller that will set up traces and push them.
func NewTraceInstaller(prov *qpotel.Provider) (*TraceInstaller, error) {
	return &TraceInstaller{
		insecure: false,
		prov:     prov,
	}, nil
}

// Insecure instructs the TraceInstaller to trust incoming trace IDs.
func (t *TraceInstaller) Insecure() {
	t.insecure = true
}

// Install adds tracing middleware to the supplied chi.Router.
// extraOpts take precedence over the default opts.
func (t *TraceInstaller) Install(r chi.Router, serviceName string, extraOpts ...otelhttp.Option) {
	if t.prov == nil {
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

	p := t.prov.NewTracerProvider(res)
	m := t.prov.NewMeterProvider(res)

	defaultOpts := []otelhttp.Option{
		otelhttp.WithTracerProvider(p),
		// TODO: Fix this
		otelhttp.WithMeterProvider(m),
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
