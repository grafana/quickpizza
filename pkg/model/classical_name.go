package model

import (
	"github.com/uptrace/bun"
)

type ClassicalName struct {
	bun.BaseModel
	Name string `json:"name" bun:",pk"`
}
