package logging

import (
	"context"

	"log/slog"

	"go.opentelemetry.io/otel/trace"
)

type ContextLogger struct {
	parent slog.Handler
}

func NewContextLogger(parent slog.Handler) *ContextLogger {
	return &ContextLogger{parent}
}

func (c *ContextLogger) Enabled(ctx context.Context, level slog.Level) bool {
	return c.parent.Enabled(ctx, level)
}

func (c *ContextLogger) Handle(ctx context.Context, record slog.Record) error {
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

func (c *ContextLogger) WithAttrs(attrs []slog.Attr) slog.Handler {
	return NewContextLogger(c.parent.WithAttrs(attrs))
}
func (c *ContextLogger) WithGroup(name string) slog.Handler {
	return NewContextLogger(c.parent.WithGroup(name))
}
