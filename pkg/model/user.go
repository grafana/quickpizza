package model

import (
	"errors"
	"math/rand"

	"github.com/uptrace/bun"
)

const (
	UserTokenLength = 16
	MaxNameLength   = 32
)

var characters = []rune("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789")

func GenerateUserToken() string {
	data := make([]rune, UserTokenLength)
	for i := range data {
		// NOTE: This should use a cryptographically-safe random
		// number generator instead.
		data[i] = characters[rand.Intn(len(characters))]
	}
	return string(data)
}

func (u *User) Validate() error {
	switch {
	case u.Name == "":
		return errors.New("name field is empty")
	case len(u.Name) > MaxNameLength:
		return errors.New("name field is too long")
	case u.Name == "default":
		return errors.New("name field is invalid")
	default:
		return nil
	}
}

type User struct {
	bun.BaseModel
	ID       int64  `bun:",pk,autoincrement"`
	Name     string `json:"name"`
	Token    string `json:"token"`
	Password string `json:"-"`
}
