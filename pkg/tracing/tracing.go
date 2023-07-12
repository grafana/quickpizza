package tracing

import (
	"context"
	"fmt"
	"net/url"

	"go.opentelemetry.io/otel/exporters/otlp/otlptrace"
	"go.opentelemetry.io/otel/exporters/otlp/otlptrace/otlptracegrpc"
	"go.opentelemetry.io/otel/exporters/otlp/otlptrace/otlptracehttp"
	"go.opentelemetry.io/otel/sdk/resource"
	sdktrace "go.opentelemetry.io/otel/sdk/trace"
	semconv "go.opentelemetry.io/otel/semconv/v1.17.0"
	"go.opentelemetry.io/otel/trace"
)

// OTLPProvider returns a TracerProvider configured to push traces to the given OTLP endpoint.
// HTTP, HTTPS, or GRPC transport will be used depending on the scheme specified in endpointUrl.
func OTLPProvider(ctx context.Context, endpointUrl string) (trace.TracerProvider, error) {
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
	}

	exporter, err := otlptrace.New(ctx, client)
	if err != nil {
		return nil, fmt.Errorf("building otlp exporter: %w", err)
	}

	res, err := resource.Merge(
		resource.Default(),
		resource.NewWithAttributes(
			semconv.SchemaURL,
			semconv.ServiceName("QuickPizza"),
		),
	)
	if err != nil {
		return nil, fmt.Errorf("building trace resources: %w", err)
	}

	return sdktrace.NewTracerProvider(
		sdktrace.WithBatcher(exporter),
		sdktrace.WithResource(res),
	), nil
}
