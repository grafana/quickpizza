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
// Install dispatches on InstrumentationMode:
//   - "sdk" (otel-sdk.go, the default): this app's own OTel Go SDK instruments itself.
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

// InstrumentationMode reports the value of QUICKPIZZA_OTEL_INSTRUMENTATION_MODE,
// defaulting to "sdk". See docs/otel.md for what each mode does. Exported for NewOTelHTTPTransport
// and QuickPizzaTracer below, which are the only mode-aware call sites outside Install's own
// dispatch; callers like pkg/http/http.go go through those instead of checking the mode
// themselves.
//
//   - "sdk" (default, otel-sdk.go): this app's own OTel Go SDK creates and exports every
//     span/metric, as it always has.
//   - "obi": every span and metric this app would otherwise produce is left for an external
//     OBI (OpenTelemetry eBPF Instrumentation) sidecar to capture instead.
func InstrumentationMode() string {
	mode, ok := os.LookupEnv("QUICKPIZZA_OTEL_INSTRUMENTATION_MODE")
	if !ok || mode == "" {
		return "sdk"
	}
	return mode
}

// Install sets up tracing/metrics for the given chi.Router, using whichever implementation
// InstrumentationMode selects. extraOpts take precedence over installSDK's default otelhttp
// options; ignored entirely in "obi" mode, since that mode does nothing here — see
// InstrumentationMode.
func (t *OTelInstaller) Install(r chi.Router, serviceComponent string, extraOpts ...otelhttp.Option) error {
	if InstrumentationMode() == "obi" {
		// OBI captures HTTP spans/metrics itself, via eBPF, from outside this process.
		// Running otelhttp here too would just duplicate them.
		return nil
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

// QuickPizzaTracer returns the trace.Tracer that a manual, non-HTTP/DB business-logic span
// (e.g. pkg/http/http.go's pizza-generation/name-generation spans) should start from for the
// request carried by ctx, dispatched by InstrumentationMode:
//
//   - "sdk": the TracerProvider tied to the current request's own HTTP server span, i.e. the
//     specific component's Install() call that handled this request. Deriving it this way
//     (rather than from otel.GetTracerProvider) keeps these spans attributed to that
//     component's own resource, since only the first-registered component's TracerProvider
//     ever becomes global (see the TODO in otel-sdk.go's installSDK).
//
//   - "obi": the plain global tracer (otel.Tracer), never ctx-derived — deliberately, not by
//     oversight. In this mode Install never runs, so this app never puts an HTTP span into
//     ctx in the first place; deriving a tracer from "whatever span is in ctx" would just
//     find nothing and silently produce dead spans that go nowhere. OBI's own agent watches
//     for exactly this plain global tracer and turns its calls into real, exported spans —
//     which is the whole reason this still works without this app running any SDK of its
//     own. See docs/otel.md's "Two instrumentation modes" section.
func QuickPizzaTracer(ctx context.Context) trace.Tracer {
	if InstrumentationMode() == "obi" {
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
	return InstrumentationMode() != "obi"
}
