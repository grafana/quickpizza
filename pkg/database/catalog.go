package database

import (
	"context"

	"github.com/grafana/quickpizza/pkg/database/migrations"
	"github.com/grafana/quickpizza/pkg/model"
	"golang.org/x/exp/slog"

	"github.com/uptrace/bun"
	"github.com/uptrace/bun/migrate"
)

type Catalog struct {
	db *bun.DB
}

func NewCatalog(connString string) (*Catalog, error) {
	db, err := initializeDB(connString)
	if err != nil {
		return nil, err
	}
	log := slog.With("db", "catalog")
	mig := migrate.NewMigrator(db, migrations.Catalog)
	if err := mig.Init(context.Background()); err != nil {
		return nil, err
	}
	log.Info("running migrations")
	g, err := mig.Migrate(context.Background())
	log.Info("applied migrations", "count", len(g.Migrations.Applied()))
	if err != nil {
		return nil, err
	}
	db.RegisterModel((*model.PizzaToIngredients)(nil))
	return &Catalog{
		db: db,
	}, nil
}

func (c *Catalog) GetIngredients(ctx context.Context, t string, vegetarian bool) ([]model.Ingredient, error) {
	var ingredients []model.Ingredient
	err := c.db.NewSelect().Model(&ingredients).Where("type = ?", t).WhereGroup(" AND ", func(q *bun.SelectQuery) *bun.SelectQuery {
		return q.Where("NOT ?", vegetarian).WhereOr("vegetarian = true")
	}).Scan(ctx)
	return ingredients, err
}

func (c *Catalog) GetDoughs(ctx context.Context) ([]model.Dough, error) {
	var doughs []model.Dough
	err := c.db.NewSelect().Model(&doughs).Scan(ctx)
	return doughs, err
}

func (c *Catalog) GetTools(ctx context.Context) ([]string, error) {
	var tools []string
	err := c.db.NewSelect().Model(&model.Tool{}).Column("name").Scan(ctx, &tools)
	return tools, err
}

func (c *Catalog) GetHistory(ctx context.Context, limit int) ([]model.Pizza, error) {
	var history []model.Pizza
	err := c.db.NewSelect().Model(&history).Relation("Dough").Relation("Ingredients").Order("CreatedAt DESC").Limit(limit).Scan(ctx)
	return history, err
}

func (c *Catalog) CreatePizza(ctx context.Context, pizza model.Pizza) error {
	pizza.DoughID = pizza.Dough.ID
	return c.db.RunInTx(ctx, nil, func(ctx context.Context, tx bun.Tx) error {
		_, err := tx.NewInsert().Model(&pizza).Exec(ctx)
		if err != nil {
			return err
		}
		for _, i := range pizza.Ingredients {
			_, err = tx.NewInsert().Model(&model.PizzaToIngredients{PizzaID: pizza.ID, IngredientID: i.ID}).Exec(ctx)
			if err != nil {
				return err
			}
		}
		return nil
	})
}
