package model

import (
	"github.com/uptrace/bun"
)

type Dough struct {
	bun.BaseModel
	ID               int64  `bun:",pk"`
	Name             string `json:"name"`
	CaloriesPerSlice int    `json:"caloriesPerSlice"`
}
