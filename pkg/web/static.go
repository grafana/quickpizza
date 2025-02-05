package web

import (
	"embed"
)

//go:embed static
var Static embed.FS

//go:embed test.k6.io
var TestK6IO embed.FS
