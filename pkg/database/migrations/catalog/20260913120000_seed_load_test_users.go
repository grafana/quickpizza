package catalog

import (
	"context"
	"embed"

	"github.com/uptrace/bun"
	"github.com/uptrace/bun/dbfixture"
	"github.com/uptrace/bun/dialect/pgdialect"

	"github.com/grafana/quickpizza/pkg/model"
)

//go:embed testdata_load_test_users.yaml
var loadTestUsersFixture embed.FS

func init() {
	Migrations.MustRegister(func(ctx context.Context, db *bun.DB) error {
		// On a database where earlier migrations are already applied, their
		// bodies (and the implicit model registration that Model() calls
		// perform) never run in this process, so dbfixture can't resolve
		// "model: User" in the YAML without this.
		db.RegisterModel((*model.User)(nil))

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
