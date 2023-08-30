package logging

import (
	"context"
	"time"

	"github.com/uptrace/bun"
	"golang.org/x/exp/slog"
)

// validate interface compliance
var _ bun.QueryHook = (*BunSlogHook)(nil)

type BunSlogHook struct {
	logger *slog.Logger
}

func NewBunSlogHook(logger *slog.Logger) *BunSlogHook {
	return &BunSlogHook{logger: logger}
}

func (h *BunSlogHook) BeforeQuery(
	ctx context.Context, event *bun.QueryEvent,
) context.Context {
	return ctx
}

func (h *BunSlogHook) AfterQuery(ctx context.Context, event *bun.QueryEvent) {
	now := time.Now()
	dur := now.Sub(event.StartTime)

	if event.Err != nil {
		h.logger.WarnContext(ctx, "failed to perform db query", "operation", event.Operation(), "duration", dur, "query", event.Query, "err", event.Err)
	} else {
		h.logger.DebugContext(ctx, "performed db query", "operation", event.Operation(), "duration", dur, "query", event.Query)
	}
}
