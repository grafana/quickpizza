package web

import "embed"

//go:embed all:build
var EmbeddedFiles embed.FS
