package model

import (
	"github.com/uptrace/bun"
)

type Rating struct {
	bun.BaseModel
	ID      int64  `json:"id" bun:",pk,autoincrement"`
	Stars   int    `json:"stars"`
	UserID  int64  `json:"-"`
	User    *User  `json:"-" bun:"rel:belongs-to,join:user_id=id"`
	PizzaID int64  `json:"-"`
	Pizza   *Pizza `json:"-" bun:"rel:belongs-to,join:pizza_id=id"`
}
