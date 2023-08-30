package copy

import (
	"context"

	"github.com/grafana/quickpizza/pkg/model"
	"github.com/uptrace/bun"
)

func init() {
	Migrations.MustRegister(func(ctx context.Context, db *bun.DB) error {
		models := []interface{}{
			&model.Quote{},
			&model.Adjective{},
			&model.ClassicalName{},
		}
		for _, i := range models {
			if _, err := db.NewCreateTable().Model(i).IfNotExists().Exec(ctx); err != nil {
				return err
			}
		}
		return nil
	}, func(ctx context.Context, db *bun.DB) error {
		return nil
	})
}
