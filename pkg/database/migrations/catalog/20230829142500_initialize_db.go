package catalog

import (
	"context"

	"github.com/grafana/quickpizza/pkg/model"
	"github.com/uptrace/bun"
)

func init() {
	Migrations.MustRegister(func(ctx context.Context, db *bun.DB) error {
		db.RegisterModel(&model.PizzaToIngredients{})
		models := []interface{}{
			&model.Ingredient{},
			&model.Dough{},
			&model.Tool{},
			&model.Pizza{},
			&model.PizzaToIngredients{},
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
