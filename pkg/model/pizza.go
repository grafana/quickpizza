package model

import (
	"time"
)

type Pizza struct {
	ID          int64        `json:"id" bun:",pk,autoincrement"`
	CreatedAt   time.Time    `json:"-" bun:",nullzero,notnull,default:current_timestamp"`
	Name        string       `json:"name"`
	DoughID     int64        `json:"-"`
	Dough       Dough        `json:"dough" bun:"rel:belongs-to,join:dough_id=id"`
	Ingredients []Ingredient `json:"ingredients" bun:"m2m:pizza_to_ingredients,join:Pizza=Ingredient"`
	Tool        string       `json:"tool"`
}

const MaxPizzaNameLength = 64

func (p Pizza) IsVegetarian() bool {
	for _, ingredient := range p.Ingredients {
		if !ingredient.Vegetarian {
			return false
		}
	}
	return true
}

func (p Pizza) CalculateCalories() int {
	calories := 0
	for _, ingredient := range p.Ingredients {
		calories += ingredient.CaloriesPerSlice
	}
	return calories
}

type PizzaToIngredients struct {
	PizzaID      int64       `bun:",pk"`
	Pizza        *Pizza      `bun:"rel:belongs-to,join:pizza_id=id"`
	IngredientID int64       `bun:",pk"`
	Ingredient   *Ingredient `bun:"rel:belongs-to,join:ingredient_id=id"`
}
