package catalog

import (
	"context"
	"embed"

	"github.com/uptrace/bun"
	"github.com/uptrace/bun/dbfixture"
	"github.com/uptrace/bun/dialect/pgdialect"
)

//go:embed testdata.yaml
var f embed.FS

func init() {
	Migrations.MustRegister(func(ctx context.Context, db *bun.DB) error {
		fixture := dbfixture.New(db)
		if err := fixture.Load(ctx, f, "testdata.yaml"); err != nil {
			return err
		}

		// Reset PostgreSQL sequence after loading fixtures with explicit IDs
		// SQLite handles autoincrement correctly without this
		if _, ok := db.Dialect().(*pgdialect.Dialect); ok {
			_, err := db.ExecContext(ctx, "SELECT setval('pizzas_id_seq', (SELECT MAX(id) FROM pizzas))")
			return err
		}

		return nil
	}, func(ctx context.Context, db *bun.DB) error {
		return nil
	})
}
