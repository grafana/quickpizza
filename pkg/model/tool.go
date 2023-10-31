package model

import (
	"github.com/uptrace/bun"
)

type Tool struct {
	bun.BaseModel
	Name string `json:"name" bun:",pk"`
}
