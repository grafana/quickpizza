package catalog

import (
	"context"
	"embed"
	"fmt"

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
			for _, reset := range []struct {
				seq, table string
			}{
				{"pizzas_id_seq", "pizzas"},
				{"users_id_seq", "users"},
				{"ratings_id_seq", "ratings"},
			} {
				q := fmt.Sprintf(
					"SELECT setval('%s', COALESCE((SELECT MAX(id) FROM %s), 1))",
					reset.seq, reset.table,
				)
				if _, err := db.ExecContext(ctx, q); err != nil {
					return err
				}
			}
		}

		return nil
	}, func(ctx context.Context, db *bun.DB) error {
		return nil
	})
}
