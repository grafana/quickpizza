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
			&model.User{},
		}
		for _, i := range models {
			if _, err := db.NewCreateTable().Model(i).IfNotExists().Exec(ctx); err != nil {
				return err
			}
		}
		_, err := db.NewCreateTable().
			Model(&model.Pizza{}).
			ForeignKey(`("dough_id") REFERENCES "doughs" ("id")`).
			ForeignKey(`("tool") REFERENCES "tools" ("name")`).
			IfNotExists().
			Exec(ctx)
		if err != nil {
			return err
		}

		_, err = db.NewCreateTable().
			Model(&model.Rating{}).
			ForeignKey(`("user_id") REFERENCES "users" ("id") ON DELETE CASCADE`).
			ForeignKey(`("pizza_id") REFERENCES "pizzas" ("id") ON DELETE CASCADE`).
			IfNotExists().
			Exec(ctx)
		if err != nil {
			return err
		}
		_, err = db.NewCreateTable().
			Model(&model.PizzaToIngredients{}).
			ForeignKey(`("pizza_id") REFERENCES "pizzas" ("id") ON DELETE CASCADE`).
			ForeignKey(`("ingredient_id") REFERENCES "ingredients" ("id")`).
			IfNotExists().
			Exec(ctx)
		if err != nil {
			return err
		}
		return nil
	}, func(ctx context.Context, db *bun.DB) error {
		return nil
	})
}
