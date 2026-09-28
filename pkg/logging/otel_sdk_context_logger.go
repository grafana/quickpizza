package logging

import (
	"context"

	"log/slog"

	"go.opentelemetry.io/otel/trace"
)

// OTelSDKContextLogger extends ContextLogger with the one thing "sdk" mode needs that "obi" mode
// doesn't: it reads the current OTel span from ctx and attaches its trace ID to every log
// record, on top of ContextLogger's own user-field behavior. This is manual instrumentation,
// required because nothing else correlates a log line with a trace in "sdk" mode unless
// application code does it explicitly - which is exactly what this type adds.
type OTelSDKContextLogger struct {
	*ContextLogger
}

func NewOTelSDKContextLogger(parent slog.Handler) *OTelSDKContextLogger {
	return &OTelSDKContextLogger{NewContextLogger(parent)}
}

func (c *OTelSDKContextLogger) Handle(ctx context.Context, record slog.Record) error {
	span := trace.SpanFromContext(ctx)
	if span.SpanContext().HasTraceID() {
		record.Add("trace_id", span.SpanContext().TraceID())
	}
	return c.ContextLogger.Handle(ctx, record)
}

func (c *OTelSDKContextLogger) WithAttrs(attrs []slog.Attr) slog.Handler {
	return NewOTelSDKContextLogger(c.parent.WithAttrs(attrs))
}
func (c *OTelSDKContextLogger) WithGroup(name string) slog.Handler {
	return NewOTelSDKContextLogger(c.parent.WithGroup(name))
}
