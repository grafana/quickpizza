package http

import (
	"context"
	"fmt"
	"net/http"
	"net/url"
	"os"

	"github.com/go-chi/chi/v5"
	"go.opentelemetry.io/contrib/instrumentation/net/http/otelhttp"
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
// defaulting to "sdk". See docs/otel.md for what each mode does. Exported because a few
// call sites outside Install's own dispatch need to check it directly: NewOTelHTTPTransport
// below, and pkg/http/http.go's recommendations handler (which needs a mode-appropriate
// tracer, not just a mode-appropriate otelhttp wrapper).
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
