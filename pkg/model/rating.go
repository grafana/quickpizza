package model

import (
	"github.com/uptrace/bun"
)

type Rating struct {
	bun.BaseModel
	ID      int64  `bun:",pk,autoincrement"`
	Stars   int    `json:"stars" bun:",pk"`
	UserID  int64  `json:"-"`
	User    *User  `bun:"rel:belongs-to,join:user_id=id"`
	PizzaID int64  `json:"-"`
	Pizza   *Pizza `bun:"rel:belongs-to,join:pizza_id=id"`
}
