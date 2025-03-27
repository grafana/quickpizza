package model

import (
	"errors"

	"github.com/uptrace/bun"
)

const (
	UserTokenLength   = 16
	MaxUserNameLength = 32
)

const GlobalUsername = "default"

func (u *User) Validate() error {
	switch {
	case u.Username == "":
		return errors.New("username field is empty")
	case len(u.Username) > MaxUserNameLength:
		return errors.New("username field is too long")
	case u.Username == GlobalUsername:
		return errors.New("username field is invalid")
	case u.Password == "":
		return errors.New("password is empty")
	default:
		return nil
	}
}

type User struct {
	bun.BaseModel
	ID                int64  `json:"id" bun:",pk,autoincrement"`
	Username          string `json:"username" bun:",unique"`
	Token             string `json:"token,omitempty" bun:",unique"`
	Password          string `json:"password,omitempty" bun:"-"` // Only used for JSON
	PasswordHash      string `json:"-"`
	PasswordPlaintext string `json:"-"` // Only used for users created via testdata.yaml
}

func (u *User) IsGlobal() bool {
	return u.Username == GlobalUsername
}
