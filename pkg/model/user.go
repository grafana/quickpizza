package model

import (
	"github.com/uptrace/bun"
)

type User struct {
	bun.BaseModel
	ID    int64  `bun:",pk,autoincrement"`
	Name  string `json:"name"`
	Token string `json:"token"`
}
