package logging

import (
	"context"

	"log/slog"
)

// ContextLogger is this app's default structured-logging wrapper: it attaches the current
// user (if present in ctx) to every log record and otherwise passes through to its parent
// handler. Nothing here reads or attaches trace context - this is exactly the logger "obi"
// mode uses, unmodified, since OBI needs no application code to correlate logs with traces
// (see otel_sdk_context_logger.go's OTelSDKContextLogger for the extra code "sdk" mode layers on
// top of this one to get the same result manually).
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
	return c.parent.Handle(ctx, record)
}

func (c *ContextLogger) WithAttrs(attrs []slog.Attr) slog.Handler {
	return NewContextLogger(c.parent.WithAttrs(attrs))
}
func (c *ContextLogger) WithGroup(name string) slog.Handler {
	return NewContextLogger(c.parent.WithGroup(name))
}
