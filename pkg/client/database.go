package client

import (
	"context"
	"fmt"

	"github.com/grafana/quickpizza/pkg/database"
	"github.com/grafana/quickpizza/pkg/pizza"
	"go.opentelemetry.io/otel/trace"
)

type CatalogDB struct {
	Database *database.InMemoryDatabase
	Ctx      context.Context
}

func (c CatalogDB) WithContext(ctx context.Context) Catalog {
	c.Ctx = ctx
	return c
}

func (c CatalogDB) Ingredients(ingredientType string) ([]pizza.Ingredient, error) {
	_, span := trace.SpanFromContext(c.Ctx).TracerProvider().Tracer("").Start(
		c.Ctx,
		"db-ingredients",
	)
	defer span.End()

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
	_, span := trace.SpanFromContext(c.Ctx).TracerProvider().Tracer("").Start(
		c.Ctx,
		"db-tools",
	)
	defer span.End()

	var tools []string
	c.Database.Transaction(func(data database.Data) {
		tools = data.Tools
	})

	return tools, nil
}

func (c CatalogDB) Doughs() ([]pizza.Dough, error) {
	_, span := trace.SpanFromContext(c.Ctx).TracerProvider().Tracer("").Start(
		c.Ctx,
		"db-doughs",
	)
	defer span.End()

	var doughs []pizza.Dough
	c.Database.Transaction(func(data database.Data) {
		doughs = data.Doughs
	})

	return doughs, nil
}

func (c CatalogDB) RecordRecommendation(p pizza.Pizza) error {
	_, span := trace.SpanFromContext(c.Ctx).TracerProvider().Tracer("").Start(
		c.Ctx,
		"db-store-recommendation",
	)
	defer span.End()

	c.Database.SetLatestPizza(p)
	return nil
}

type CopyDB struct {
	Database *database.InMemoryDatabase
	Ctx      context.Context
}

func (c CopyDB) WithContext(ctx context.Context) Copy {
	c.Ctx = ctx
	return c
}

func (c CopyDB) Adjectives() ([]string, error) {
	_, span := trace.SpanFromContext(c.Ctx).TracerProvider().Tracer("").Start(
		c.Ctx,
		"db-adjectives",
	)
	defer span.End()

	var adjs []string
	c.Database.Transaction(func(data database.Data) {
		adjs = data.Adjectives
	})

	return adjs, nil
}

func (c CopyDB) Names() ([]string, error) {
	_, span := trace.SpanFromContext(c.Ctx).TracerProvider().Tracer("").Start(
		c.Ctx,
		"db-names",
	)
	defer span.End()

	var names []string
	c.Database.Transaction(func(data database.Data) {
		names = data.ClassicNames
	})

	return names, nil
}
