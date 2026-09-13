package catalog

import (
	"context"
	"embed"

	"github.com/uptrace/bun"
	"github.com/uptrace/bun/dbfixture"
	"github.com/uptrace/bun/dialect/pgdialect"
)

//go:embed testdata_load_test_users.yaml
var loadTestUsersFixture embed.FS

func init() {
	Migrations.MustRegister(func(ctx context.Context, db *bun.DB) error {
		fixture := dbfixture.New(db)
		if err := fixture.Load(ctx, loadTestUsersFixture, "testdata_load_test_users.yaml"); err != nil {
			return err
		}

		// Reset PostgreSQL sequence after loading fixtures with explicit IDs.
		// SQLite handles autoincrement correctly without this.
		if _, ok := db.Dialect().(*pgdialect.Dialect); ok {
			_, err := db.ExecContext(ctx, "SELECT setval('users_id_seq', COALESCE((SELECT MAX(id) FROM users), 1))")
			if err != nil {
				return err
			}
		}

		return nil
	}, func(ctx context.Context, db *bun.DB) error {
		return nil
	})
}
