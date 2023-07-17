package client

import (
	"context"
	"fmt"

	"github.com/grafana/quickpizza/pkg/database"
	"github.com/grafana/quickpizza/pkg/pizza"
)

type CatalogDB struct {
	Database *database.InMemoryDatabase
}

// WithContext returns the same CatalogDB client as it does not use the context for anything.
func (c CatalogDB) WithContext(_ context.Context) Catalog {
	return c
}

func (c CatalogDB) Ingredients(ingredientType string) ([]pizza.Ingredient, error) {
	var ingredients []pizza.Ingredient
	var err error
	c.Database.Transaction(func(data database.Data) {
		switch ingredientType {
		case "olive_oil":
			ingredients = data.OliveOils
		case "tomato":
			ingredients = data.Tomatoes
		case "mozzarella":
			ingredients = data.Mozzarellas
		case "topping":
			ingredients = data.Toppings
		default:
			err = fmt.Errorf("unknown ingredient type %q", ingredientType)
		}
	})
	if err != nil {
		return nil, err
	}

	return ingredients, nil
}

func (c CatalogDB) Tools() ([]string, error) {
	var tools []string
	c.Database.Transaction(func(data database.Data) {
		tools = data.Tools
	})

	return tools, nil
}

func (c CatalogDB) Doughs() ([]pizza.Dough, error) {
	var doughs []pizza.Dough
	c.Database.Transaction(func(data database.Data) {
		doughs = data.Doughs
	})

	return doughs, nil
}

func (c CatalogDB) RecordRecommendation(p pizza.Pizza) error {
	c.Database.SetLatestPizza(p)
	return nil
}

type CopyDB struct {
	Database *database.InMemoryDatabase
}

// WithContext returns the same CopyDB client as it does not use the context for anything.
func (c CopyDB) WithContext(_ context.Context) Copy {
	return c
}

func (c CopyDB) Adjectives() ([]string, error) {
	var adjs []string
	c.Database.Transaction(func(data database.Data) {
		adjs = data.Adjectives
	})

	return adjs, nil
}

func (c CopyDB) Names() ([]string, error) {
	var names []string
	c.Database.Transaction(func(data database.Data) {
		names = data.ClassicNames
	})

	return names, nil
}
