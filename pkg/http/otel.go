package http

import (
	"context"
	"fmt"
	"net/http"
	"net/url"
	"os"

	"github.com/go-chi/chi/v5"
	"go.opentelemetry.io/contrib/instrumentation/net/http/otelhttp"
	"go.opentelemetry.io/otel"
	"go.opentelemetry.io/otel/trace"
)

// OTelInstaller installs tracing middleware into a chi router.
// An uninitialized OTelInstaller behaves like a noop, where calls to Install have no effect.
//
// Install dispatches to one of two independent implementations depending on
// InstrumentationMode:
//   - installSDK (otel-sdk.go, the default): this app's own OTel Go SDK instruments itself.
//   - installOBI (otel-obi.go): a deliberate no-op — an external OBI sidecar instruments
//     this process entirely from outside it, via eBPF, with zero code in this app.
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
// defaulting to "sdk". See docs/otel.md for what each mode does. Exported for NewOTelHTTPTransport
// and BusinessTracer below, which are the only mode-aware call sites outside Install's own
// dispatch; callers like pkg/http/http.go go through those instead of checking the mode
// themselves.
//
//   - "sdk" (default, otel-sdk.go): this app's own OTel Go SDK creates and exports every
//     span/metric, as it always has.
//   - "obi" (otel-obi.go): every span and metric this app would otherwise produce is left
//     for an external OBI (OpenTelemetry eBPF Instrumentation) sidecar to capture instead.
func InstrumentationMode() string {
	mode, ok := os.LookupEnv("QUICKPIZZA_OTEL_INSTRUMENTATION_MODE")
	if !ok || mode == "" {
		return "sdk"
	}
	return mode
}

// Install sets up tracing/metrics for the given chi.Router, using whichever implementation
// InstrumentationMode selects. extraOpts take precedence over installSDK's default otelhttp
// options; installOBI ignores them entirely, since it does nothing.
func (t *OTelInstaller) Install(r chi.Router, serviceComponent string, extraOpts ...otelhttp.Option) error {
	if InstrumentationMode() == "obi" {
		return t.installOBI()
	}
	return t.installSDK(r, serviceComponent, extraOpts...)
}

// NewOTelHTTPTransport wraps base with otelhttp instrumentation, unless InstrumentationMode
// is "obi" (in which case base is returned unchanged), since OBI already captures this HTTP
// traffic via eBPF and app-side otelhttp would just duplicate it. Shared by every caller that
// builds its own instrumented HTTP client instead of going through Install: cmd/main.go's
// recommendations→catalog/copy client, and pkg/http/http.go's gateway reverse-proxy transport.
func NewOTelHTTPTransport(base http.RoundTripper, opts ...otelhttp.Option) http.RoundTripper {
	if InstrumentationMode() == "obi" {
		return base
	}
	return otelhttp.NewTransport(base, opts...)
}

// BusinessTracer returns the trace.Tracer that a manual, non-HTTP/DB business-logic span
// (e.g. pkg/http/http.go's pizza-generation/name-generation spans) should start from for the
// request carried by ctx, dispatched by InstrumentationMode:
//   - "sdk": the TracerProvider tied to the current request's own HTTP server span, i.e. the
//     specific component's Install() call that handled this request. Deriving it this way
//     (rather than from otel.GetTracerProvider) keeps these spans attributed to that
//     component's own resource, since only the first-registered component's TracerProvider
//     ever becomes global (see the TODO in otel-sdk.go's installSDK).
//   - "obi": the plain, unregistered global tracer. There is no span in ctx to derive one
//     from anyway, since otelhttp never runs in this mode; using the global accessor is what
//     lets OBI's Go Trace API bridge auto-activate for these calls instead (see otel-obi.go
//     and docs/otel.md).
func BusinessTracer(ctx context.Context) trace.Tracer {
	if InstrumentationMode() == "obi" {
		return otel.Tracer("quickpizza")
	}
	return trace.SpanFromContext(ctx).TracerProvider().Tracer("")
}
