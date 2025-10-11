package util

import (
	"math/rand"
	"os"
	"strconv"
	"time"
)

const (
	MaxUserNameLength = 32
)

var characters = []rune("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789")

func GenerateAlphaNumToken(length int) string {
	data := make([]rune, length)
	for i := range data {
		// NOTE: This should use a cryptographically-safe random
		// number generator instead.
		data[i] = characters[rand.Intn(len(characters))]
	}
	return string(data)
}

// DelayIfEnvSet applies a delay in milliseconds if the specified environment variable is set.
// The environment variable should contain an integer value representing milliseconds.
func DelayIfEnvSet(envVarName string) {
	if delayStr, ok := os.LookupEnv(envVarName); ok {
		delayMs, _ := strconv.Atoi(delayStr)
		time.Sleep(time.Duration(delayMs) * time.Millisecond)
	}
}
