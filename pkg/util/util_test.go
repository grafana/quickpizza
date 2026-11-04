package util

import (
	"slices"
	"testing"
	"time"
)

func TestDelayIfEnvSet(t *testing.T) {
	const envVar = "TEST_QUICKPIZZA_DELAY"

	tests := []struct {
		name     string
		envValue string
		setEnv   bool
		wantMin  time.Duration
	}{
		{name: "unset env var does not delay", setEnv: false},
		{name: "invalid duration does not delay", setEnv: true, envValue: "not-a-duration"},
		{name: "valid duration delays", setEnv: true, envValue: "5ms", wantMin: 5 * time.Millisecond},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if tt.setEnv {
				t.Setenv(envVar, tt.envValue)
			}

			start := time.Now()
			DelayIfEnvSet(envVar)
			elapsed := time.Since(start)

			if elapsed < tt.wantMin {
				t.Errorf("elapsed = %v, want at least %v", elapsed, tt.wantMin)
			}
		})
	}
}

func TestFailRandomlyIfEnvSet(t *testing.T) {
	const envVar = "TEST_QUICKPIZZA_FAIL_RATE"

	tests := []struct {
		name     string
		envValue string
		setEnv   bool
		want     bool
	}{
		{name: "unset env var never fails", setEnv: false, want: false},
		{name: "invalid value never fails", setEnv: true, envValue: "not-a-number", want: false},
		{name: "negative rate never fails", setEnv: true, envValue: "-1", want: false},
		{name: "rate over 100 never fails", setEnv: true, envValue: "101", want: false},
		{name: "0 percent never fails", setEnv: true, envValue: "0", want: false},
		{name: "100 percent always fails", setEnv: true, envValue: "100", want: true},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if tt.setEnv {
				t.Setenv(envVar, tt.envValue)
			}

			got := FailRandomlyIfEnvSet(envVar)
			if got != tt.want {
				t.Errorf("FailRandomlyIfEnvSet() = %v, want %v", got, tt.want)
			}
		})
	}
}

func TestGenerateAlphaNumToken(t *testing.T) {
	const length = 24

	token := GenerateAlphaNumToken(length)

	if len(token) != length {
		t.Fatalf("len(token) = %d, want %d", len(token), length)
	}

	for _, r := range token {
		if !slices.Contains(characters, r) {
			t.Errorf("token contains unexpected character %q", r)
		}
	}
}
