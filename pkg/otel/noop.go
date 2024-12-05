package otel

import (
	"context"

	lognoop "go.opentelemetry.io/otel/log/noop"
	metricnoop "go.opentelemetry.io/otel/metric/noop"
	"go.opentelemetry.io/otel/sdk/metric"
	"go.opentelemetry.io/otel/sdk/metric/metricdata"
	"go.opentelemetry.io/otel/sdk/trace"
	tracenoop "go.opentelemetry.io/otel/trace/noop"
)

func Noop() *Provider {
	return &Provider{
		traceExporter:  noopTraceExporter{},
		metricExporter: noopMetricExporter{},
		tracerProvider: tracenoop.NewTracerProvider(),
		loggerProvider: lognoop.NewLoggerProvider(),
		meterProvider:  metricnoop.NewMeterProvider(),
	}
}

type noopTraceExporter struct{}

func (noopTraceExporter) ExportSpans(_ context.Context, _ []trace.ReadOnlySpan) error {
	return nil
}

func (noopTraceExporter) Shutdown(_ context.Context) error {
	return nil
}

type noopMetricExporter struct{}

func (noopMetricExporter) Temporality(metric.InstrumentKind) metricdata.Temporality {
	return metricdata.CumulativeTemporality
}

func (noopMetricExporter) Aggregation(metric.InstrumentKind) metric.Aggregation {
	return metric.AggregationDrop{}
}

func (noopMetricExporter) Export(context.Context, *metricdata.ResourceMetrics) error {
	return nil
}

func (noopMetricExporter) ForceFlush(context.Context) error {
	return nil
}

func (noopMetricExporter) Shutdown(context.Context) error {
	return nil
}
