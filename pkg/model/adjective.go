package model

import (
	"github.com/uptrace/bun"
)

type Adjective struct {
	bun.BaseModel
	Name string `json:"name" bun:",pk"`
}
