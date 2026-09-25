package http

// installOBI is the "obi" InstrumentationMode: OBI instruments this process entirely from
// outside it, via eBPF. That covers HTTP spans, HTTP metrics, and even Go runtime metrics
// (goroutines, GC, memory, CPU — see https://opentelemetry.io/docs/zero-code/obi/metrics/),
// all with zero code in this app. So, unlike installSDK, this is a deliberate no-op: no
// TracerProvider, no MeterProvider, no TextMapPropagator, no otelhttp. Registering any of
// those would either duplicate what OBI already captures via eBPF, or — for the
// TracerProvider specifically — actively prevent OBI's Go Trace API bridge from
// auto-activating for this app's two manual business-logic spans (see
// https://opentelemetry.io/docs/zero-code/obi/distributed-traces/ and pkg/http/http.go).
// See docs/otel.md and InstrumentationMode.
func (t *OTelInstaller) installOBI() error {
	return nil
}
