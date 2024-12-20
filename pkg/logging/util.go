package logging

import (
	"log/slog"
	"os"
	"strings"
)

func GetLogLevel() slog.Level {
	switch strings.ToLower(os.Getenv("QUICKPIZZA_LOG_LEVEL")) {
	case "debug":
		return slog.LevelDebug
	case "warn":
		return slog.LevelWarn
	case "error":
		return slog.LevelError
	default:
		return slog.LevelInfo
	}
}
