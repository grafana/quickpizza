package copy

import (
	"context"
	"embed"

	"github.com/uptrace/bun"
	"github.com/uptrace/bun/dbfixture"
)

//go:embed testdata.yaml
var f embed.FS

func init() {
	Migrations.MustRegister(func(ctx context.Context, db *bun.DB) error {
		fixture := dbfixture.New(db)
		return fixture.Load(context.Background(), f, "testdata.yaml")
	}, func(ctx context.Context, db *bun.DB) error {
		return nil
	})
}
