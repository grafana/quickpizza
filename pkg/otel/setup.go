package otel

import (
	"context"
	"errors"
	"fmt"
	"net/url"

	"go.opentelemetry.io/contrib/processors/baggagecopy"
	"go.opentelemetry.io/otel"
	"go.opentelemetry.io/otel/exporters/otlp/otlplog/otlploggrpc"
	"go.opentelemetry.io/otel/exporters/otlp/otlplog/otlploghttp"
	"go.opentelemetry.io/otel/exporters/otlp/otlpmetric/otlpmetricgrpc"
	"go.opentelemetry.io/otel/exporters/otlp/otlpmetric/otlpmetrichttp"
	"go.opentelemetry.io/otel/exporters/otlp/otlptrace"
	"go.opentelemetry.io/otel/exporters/otlp/otlptrace/otlptracegrpc"
	"go.opentelemetry.io/otel/exporters/otlp/otlptrace/otlptracehttp"
	"go.opentelemetry.io/otel/log"
	"go.opentelemetry.io/otel/log/global"
	"go.opentelemetry.io/otel/metric"
	"go.opentelemetry.io/otel/propagation"
	logsdk "go.opentelemetry.io/otel/sdk/log"
	metricsdk "go.opentelemetry.io/otel/sdk/metric"
	"go.opentelemetry.io/otel/sdk/resource"
	tracesdk "go.opentelemetry.io/otel/sdk/trace"
	semconv "go.opentelemetry.io/otel/semconv/v1.17.0"
	"go.opentelemetry.io/otel/trace"
)

type ShutdownFunc func(context.Context) error

type Provider struct {
	traceExporter  tracesdk.SpanExporter
	metricExporter metricsdk.Exporter
	tracerProvider trace.TracerProvider
	loggerProvider log.LoggerProvider
	meterProvider  metric.MeterProvider
}

func (p *Provider) TracerProvider() trace.TracerProvider {
	return p.tracerProvider
}

func (p *Provider) NewTracerProvider(res *resource.Resource) trace.TracerProvider {
	return newTraceProvider(res, p.traceExporter)
}

func (p *Provider) LoggerProvider() log.LoggerProvider {
	return p.loggerProvider
}

func (p *Provider) MeterProvider() metric.MeterProvider {
	return p.meterProvider
}

func (p *Provider) NewMeterProvider(res *resource.Resource) metric.MeterProvider {
	return newMeterProvider(res, p.metricExporter)
}

// Setup bootstraps the OpenTelemetry pipeline.
// If it does not return an error, make sure to call shutdown for proper cleanup.
func Setup(ctx context.Context, endpointUrl string) (*Provider, ShutdownFunc, error) {
	u, err := url.Parse(endpointUrl)
	if err != nil {
		return nil, nil, fmt.Errorf("parsing endpoint url: %w", err)
	}

	var shutdownFuncs []ShutdownFunc
	// shutdown calls cleanup functions registered via shutdownFuncs.
	// The errors from the calls are joined.
	// Each registered cleanup will be invoked once.
	shutdown := func(ctx context.Context) error {
		var err error
		for _, fn := range shutdownFuncs {
			err = errors.Join(err, fn(ctx))
		}
		shutdownFuncs = nil
		return err
	}

	// handleErr calls shutdown for cleanup and makes sure that all errors are returned.
	handleErr := func(inErr error) error {
		return errors.Join(inErr, shutdown(ctx))
	}

	// Set up propagator.
	prop := newPropagator()
	otel.SetTextMapPropagator(prop)

	res, _ := resource.Merge(
		resource.Default(),
		resource.NewWithAttributes(
			semconv.SchemaURL,
			semconv.ServiceName("quickpizza"),
		),
	)

	// Set up trace provider.
	traceExporter, err := newTraceExporter(ctx, u)
	if err != nil {
		return nil, nil, handleErr(err)
	}

	tracerProvider := newTraceProvider(res, traceExporter)
	shutdownFuncs = append(shutdownFuncs, tracerProvider.Shutdown)
	otel.SetTracerProvider(tracerProvider)

	// TODO: Set up meter provider.
	metricExporter, err := newMetricExporter(ctx, u)
	if err != nil {
		return nil, nil, handleErr(err)
	}

	meterProvider := newMeterProvider(res, metricExporter)
	shutdownFuncs = append(shutdownFuncs, meterProvider.Shutdown)
	otel.SetMeterProvider(meterProvider)

	// Set up logger provider.
	logExporter, err := newLogExporter(ctx, u)
	if err != nil {
		return nil, nil, handleErr(err)
	}

	loggerProvider, err := newLoggerProvider(res, logExporter)
	if err != nil {
		return nil, nil, handleErr(err)
	}

	shutdownFuncs = append(shutdownFuncs, loggerProvider.Shutdown)
	global.SetLoggerProvider(loggerProvider)

	return &Provider{
		traceExporter:  traceExporter,
		metricExporter: metricExporter,
		tracerProvider: tracerProvider,
		loggerProvider: loggerProvider,
		meterProvider:  meterProvider,
	}, shutdown, nil
}

func newPropagator() propagation.TextMapPropagator {
	return propagation.NewCompositeTextMapPropagator(
		propagation.TraceContext{},
		propagation.Baggage{},
	)
}

func newTraceExporter(ctx context.Context, u *url.URL) (tracesdk.SpanExporter, error) {
	var client otlptrace.Client
	switch u.Scheme {
	case "http":
		client = otlptracehttp.NewClient()
	case "https":
		client = otlptracehttp.NewClient()
	case "grpc":
		client = otlptracegrpc.NewClient()
	default:
		return nil, fmt.Errorf("unsupported protocol %q", u.Scheme)
	}

	traceExporter, err := otlptrace.New(ctx, client)
	if err != nil {
		return nil, fmt.Errorf("building otlp exporter: %w", err)
	}

	return traceExporter, nil
}

func newLogExporter(ctx context.Context, u *url.URL) (logsdk.Exporter, error) {
	var logExporter logsdk.Exporter
	var err error
	switch u.Scheme {
	case "http":
		logExporter, err = otlploghttp.New(ctx)
	case "https":
		logExporter, err = otlploghttp.New(ctx)
	case "grpc":
		logExporter, err = otlploggrpc.New(ctx)
	default:
		return nil, fmt.Errorf("unsupported protocol %q", u.Scheme)
	}

	return logExporter, err
}

func newMetricExporter(ctx context.Context, u *url.URL) (metricsdk.Exporter, error) {
	var metricExporter metricsdk.Exporter
	var err error
	switch u.Scheme {
	case "http":
		metricExporter, err = otlpmetrichttp.New(ctx)
	case "https":
		metricExporter, err = otlpmetrichttp.New(ctx)
	case "grpc":
		metricExporter, err = otlpmetricgrpc.New(ctx)
	default:
		return nil, fmt.Errorf("unsupported protocol %q", u.Scheme)
	}

	return metricExporter, err
}

func newTraceProvider(res *resource.Resource, traceExporter tracesdk.SpanExporter) *tracesdk.TracerProvider {
	traceProvider := tracesdk.NewTracerProvider(
		tracesdk.WithResource(res),
		tracesdk.WithSpanProcessor(baggagecopy.NewSpanProcessor(baggagecopy.AllowAllMembers)),
		tracesdk.WithBatcher(traceExporter),
	)

	return traceProvider
}

func newMeterProvider(res *resource.Resource, metricExporter metricsdk.Exporter) *metricsdk.MeterProvider {
	meterProvider := metricsdk.NewMeterProvider(
		metricsdk.WithResource(res),
		metricsdk.WithReader(metricsdk.NewPeriodicReader(metricExporter)),
	)

	return meterProvider
}

func newLoggerProvider(res *resource.Resource, logExporter logsdk.Exporter) (*logsdk.LoggerProvider, error) {
	loggerProvider := logsdk.NewLoggerProvider(
		logsdk.WithResource(res),
		logsdk.WithProcessor(baggagecopy.NewLogProcessor(baggagecopy.AllowAllMembers)),
		logsdk.WithProcessor(logsdk.NewBatchProcessor(logExporter)),
	)

	return loggerProvider, nil
}
