package model

import (
	"github.com/uptrace/bun"
)

type Quote struct {
	bun.BaseModel
	Name string `json:"name" bun:",pk"`
}
