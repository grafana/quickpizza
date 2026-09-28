package logging

import (
	"context"

	"log/slog"

	"go.opentelemetry.io/otel/trace"
)

// SDKContextLogger correlates logs with traces by reading the current OTel span from ctx and
// attaching its trace ID to every log record. This is the manual instrumentation "sdk" mode
// requires: nothing correlates a log line with a trace unless application code explicitly
// reads the span out of context and attaches it, which is exactly what this type does. See
// OBIContextLogger for the "obi" mode counterpart, which deliberately does none of this.
type SDKContextLogger struct {
	parent slog.Handler
}

func NewSDKContextLogger(parent slog.Handler) *SDKContextLogger {
	return &SDKContextLogger{parent}
}

func (c *SDKContextLogger) Enabled(ctx context.Context, level slog.Level) bool {
	return c.parent.Enabled(ctx, level)
}

func (c *SDKContextLogger) Handle(ctx context.Context, record slog.Record) error {
	user := ctx.Value("user")
	if user != nil {
		record.Add("user", user)
	}
	span := trace.SpanFromContext(ctx)
	if span.SpanContext().HasTraceID() {
		record.Add("traceID", span.SpanContext().TraceID())
	}
	return c.parent.Handle(ctx, record)
}

func (c *SDKContextLogger) WithAttrs(attrs []slog.Attr) slog.Handler {
	return NewSDKContextLogger(c.parent.WithAttrs(attrs))
}
func (c *SDKContextLogger) WithGroup(name string) slog.Handler {
	return NewSDKContextLogger(c.parent.WithGroup(name))
}

// OBIContextLogger attaches the user field only - never trace context. In "obi" mode, log
// correlation (when OBI's own log_enricher is enabled - see docs/otel.md) is added by OBI
// itself, from outside this process via eBPF, by rewriting the raw log bytes this app writes
// to stdout. This type exists to make that visible in the code: unlike SDKContextLogger, it
// never touches trace context, because doing so is not this process's job in "obi" mode.
type OBIContextLogger struct {
	parent slog.Handler
}

func NewOBIContextLogger(parent slog.Handler) *OBIContextLogger {
	return &OBIContextLogger{parent}
}

func (c *OBIContextLogger) Enabled(ctx context.Context, level slog.Level) bool {
	return c.parent.Enabled(ctx, level)
}

func (c *OBIContextLogger) Handle(ctx context.Context, record slog.Record) error {
	user := ctx.Value("user")
	if user != nil {
		record.Add("user", user)
	}
	return c.parent.Handle(ctx, record)
}

func (c *OBIContextLogger) WithAttrs(attrs []slog.Attr) slog.Handler {
	return NewOBIContextLogger(c.parent.WithAttrs(attrs))
}
func (c *OBIContextLogger) WithGroup(name string) slog.Handler {
	return NewOBIContextLogger(c.parent.WithGroup(name))
}
