package model

import (
	"github.com/uptrace/bun"
)

type Ingredient struct {
	bun.BaseModel    `bun:"table:ingredients,alias:i"`
	ID               int64  `bun:",pk"`
	Name             string `json:"name"`
	CaloriesPerSlice int    `json:"caloriesPerSlice"`
	Vegetarian       bool   `json:"vegetarian"`
	Type             string `json:"-"`
}
