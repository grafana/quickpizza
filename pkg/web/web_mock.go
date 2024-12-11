//+build mock

package web

import "embed"

// Embed some random directory.
//go:embed all:static
var EmbeddedFiles embed.FS
