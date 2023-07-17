package client

import (
	"context"

	"github.com/grafana/quickpizza/pkg/pizza"
)

// Catalog is a client that can return data from the catalog.
type Catalog interface {
	WithContext(ctx context.Context) Catalog

	Ingredients(ingredientType string) ([]pizza.Ingredient, error)
	Tools() ([]string, error)
	Doughs() ([]pizza.Dough, error)
	RecordRecommendation(p pizza.Pizza) error
}

// Copy is a client that can return copywriting data.
type Copy interface {
	WithContext(ctx context.Context) Copy

	Adjectives() ([]string, error)
	Names() ([]string, error)
}
