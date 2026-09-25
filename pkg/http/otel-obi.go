package http

import (
	"context"
	"fmt"
	"time"

	"github.com/go-chi/chi/v5"
	"go.opentelemetry.io/contrib/instrumentation/runtime"
	"go.opentelemetry.io/otel"
	"go.opentelemetry.io/otel/propagation"
	sdkmetric "go.opentelemetry.io/otel/sdk/metric"
	"go.opentelemetry.io/otel/sdk/resource"
)

// installOBI is the "obi" InstrumentationMode: HTTP and business-logic traces, plus HTTP
// metrics, are left for an external OBI (OpenTelemetry eBPF Instrumentation) sidecar to
// capture instead of this app's own SDK. See docs/otel.md and InstrumentationMode.
//
// Crucially, this never registers a TracerProvider and never runs otelhttp:
//   - Running otelhttp here too would duplicate the HTTP spans/metrics OBI already
//     captures via eBPF.
//   - OBI's Go Trace API bridge (see
//     https://opentelemetry.io/docs/zero-code/obi/distributed-traces/) only auto-activates
//     for a process when no SDK TracerProvider is registered — that's what lets it pick up
//     this app's two manual business-logic spans (pkg/http/http.go's
//     otel.Tracer("quickpizza").Start calls) even though this app runs no SDK trace
//     exporter of its own in this mode.
//
// A real MeterProvider is still created for Go runtime metrics (goroutines, GC, ...), since
// OBI doesn't produce those.
func (t *OTelInstaller) installOBI(r chi.Router, res *resource.Resource, protocol string) error {
	ctx := context.Background()
	var mp *sdkmetric.MeterProvider

	if t.endpoint == nil {
		// If endpoint is nil, use a no-op provider (local metrics only)
		mp = sdkmetric.NewMeterProvider()
	} else {
		var err error
		mp, err = createMetricProvider(ctx, t.endpoint, protocol, res)
		if err != nil {
			return fmt.Errorf("creating metric provider: %w", err)
		}
	}

	if !t.installed {
		// Deliberately no otel.SetTracerProvider call here: see the doc comment above.
		otel.SetTextMapPropagator(propagation.NewCompositeTextMapPropagator(propagation.TraceContext{}, propagation.Baggage{}))
		otel.SetMeterProvider(mp)

		if err := runtime.Start(
			runtime.WithMeterProvider(mp),
			runtime.WithMinimumReadMemStatsInterval(time.Second),
		); err != nil {
			return fmt.Errorf("starting runtime instrumentation: %w", err)
		}

		t.installed = true
	}

	// No otelhttp.NewHandler, OTelRouteLabeler, or LogTraceID here: OBI captures HTTP
	// server spans/metrics itself via eBPF, and the latter two exist only to enrich the
	// span otelhttp would have created.
	return nil
}
