package otel

import (
	"context"
	"fmt"
	"log/slog"
	"net/http"
	"net/url"
	"os"

	"github.com/go-chi/chi/v5"
	"github.com/grafana/quickpizza/pkg/logging"
	"go.opentelemetry.io/contrib/instrumentation/net/http/otelhttp"
	"go.opentelemetry.io/otel"
	"go.opentelemetry.io/otel/trace"
)

// OTelInstaller installs tracing middleware into a chi router.
// An uninitialized OTelInstaller behaves like a noop, where calls to Install have no effect.
//
// Install dispatches on instrumentationMode:
//   - "sdk" (otel_sdk.go, the default): this app's own OTel Go SDK instruments itself.
//   - "obi": a deliberate no-op — an external OBI sidecar instruments this process entirely
//     from outside it, via eBPF, with zero code in this app.
//
// See docs/otel.md for what each mode does.
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

// instrumentationMode reports the value of QUICKPIZZA_OTEL_INSTRUMENTATION_MODE,
// defaulting to "sdk". See docs/otel.md for what each mode does. Unexported deliberately:
// external callers should go through Install, InstrumentHTTPTransport, QuickPizzaTracer, or
// InstrumentDatabase instead of checking the mode themselves.
//
//   - "sdk" (default, otel_sdk.go): this app's own OTel Go SDK creates and exports every
//     span/metric, as it always has.
//   - "obi": every span and metric this app would otherwise produce is left for an external
//     OBI (OpenTelemetry eBPF Instrumentation) sidecar to capture instead.
func instrumentationMode() string {
	mode, ok := os.LookupEnv("QUICKPIZZA_OTEL_INSTRUMENTATION_MODE")
	if !ok || mode == "" {
		return "sdk"
	}
	return mode
}

// Install sets up tracing/metrics for the given chi.Router, using whichever implementation
// instrumentationMode selects. extraOpts take precedence over installSDK's default otelhttp
// options; ignored entirely in "obi" mode, since that mode does nothing here — see
// instrumentationMode.
func (t *OTelInstaller) Install(r chi.Router, serviceComponent string, extraOpts ...otelhttp.Option) error {
	if instrumentationMode() == "obi" {
		// OBI captures HTTP spans/metrics itself, via eBPF, from outside this process.
		// Running otelhttp here too would just duplicate them.
		return nil
	}
	return t.installSDK(r, serviceComponent, extraOpts...)
}

// InstrumentHTTPTransport wraps base with otelhttp instrumentation, unless instrumentationMode
// is "obi" (in which case base is returned unchanged), since OBI already captures this HTTP
// traffic via eBPF and app-side otelhttp would just duplicate it. Shared by every caller that
// builds its own instrumented HTTP client instead of going through Install: cmd/main.go's
// recommendations→catalog/copy client, and pkg/http/http.go's gateway reverse-proxy transport.
func InstrumentHTTPTransport(base http.RoundTripper, opts ...otelhttp.Option) http.RoundTripper {
	if instrumentationMode() == "obi" {
		return base
	}
	return otelhttp.NewTransport(base, opts...)
}

// QuickPizzaTracer returns the trace.Tracer that a manual, non-HTTP/DB business-logic span
// (e.g. pkg/http/http.go's pizza-generation/name-generation spans) should start from for the
// request carried by ctx, dispatched by instrumentationMode:
//
//   - "sdk": the TracerProvider tied to the current request's own HTTP server span, i.e. the
//     specific component's Install() call that handled this request. Deriving it this way
//     (rather than from otel.GetTracerProvider) keeps these spans attributed to that
//     component's own resource, since only the first-registered component's TracerProvider
//     ever becomes global (see the TODO in otel_sdk.go's installSDK).
//
//   - "obi": the plain global tracer (otel.Tracer), never ctx-derived — deliberately, not by
//     oversight. In this mode Install never runs, so this app never puts an HTTP span into
//     ctx in the first place; deriving a tracer from "whatever span is in ctx" would just
//     find nothing and silently produce dead spans that go nowhere. OBI's own agent watches
//     for exactly this plain global tracer and turns its calls into real, exported spans —
//     which is the whole reason this still works without this app running any SDK of its
//     own. See docs/otel.md's "Two instrumentation modes" section.
func QuickPizzaTracer(ctx context.Context) trace.Tracer {
	if instrumentationMode() == "obi" {
		return otel.Tracer("quickpizza")
	}
	return trace.SpanFromContext(ctx).TracerProvider().Tracer("")
}

// InstrumentDatabase reports whether pkg/database should register its own DB query hook.
// False in "obi" mode: OBI already captures database queries itself, from outside the
// process, so the app's own hook would just double up every query into two spans. pkg/database
// has no OTel-mode awareness of its own; callers (cmd/main.go) pass this straight into
// database.NewCatalog/NewCopy. See docs/otel.md's "Database (Bun ORM)" row.
func InstrumentDatabase() bool {
	return instrumentationMode() != "obi"
}

// ExemplarData holds trace context that inner middleware populates for outer middleware to
// read. Callers (e.g. pkg/http/http.go's HTTPMetricsMiddleware, which runs in both modes)
// store a pointer under ExemplarKey in the request context before calling next.ServeHTTP().
// Only "sdk" mode's otelRouteLabeler (otel_sdk.go) ever writes a trace ID into it - in "obi"
// mode nothing populates it, so callers get the metrics but never an exemplar.
type ExemplarData struct {
	TraceID string
}

// exemplarKeyType is deliberately unexported: callers outside this package use the ExemplarKey
// value below as an opaque context key, but should never construct their own key of this type.
type exemplarKeyType int

const ExemplarKey exemplarKeyType = 0

// WrapLogHandler returns the slog.Handler this app's structured logs should use, dispatched by
// instrumentationMode:
//
//   - "sdk": logging.OTelSDKContextLogger, which reads the current span out of ctx and attaches
//     its trace ID to every log record - manual instrumentation, required because nothing
//     else correlates logs with traces in this mode.
//   - "obi": logging.ContextLogger, this app's plain default logger, unmodified. Log
//     correlation in this mode, if wanted, is OBI's own log_enricher feature rewriting the
//     raw log bytes from outside this process, via eBPF - zero code here does it. See
//     docs/otel.md.
func WrapLogHandler(base slog.Handler) slog.Handler {
	if instrumentationMode() == "obi" {
		return logging.NewContextLogger(base)
	}
	return logging.NewOTelSDKContextLogger(base)
}
