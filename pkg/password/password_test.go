package password

import "testing"

func TestHashAndCheckPassword_RoundTrip(t *testing.T) {
	hash, err := HashPassword("correct-horse-battery-staple")
	if err != nil {
		t.Fatalf("HashPassword() error = %v", err)
	}

	if !CheckPassword("correct-horse-battery-staple", hash) {
		t.Error("CheckPassword() = false for the password that was hashed, want true")
	}
}

func TestHashPassword_EmptyPassword(t *testing.T) {
	_, err := HashPassword("")
	if err == nil {
		t.Error("HashPassword(\"\") error = nil, want an error")
	}
}

func TestCheckPassword_WrongPassword(t *testing.T) {
	hash, err := HashPassword("correct-horse-battery-staple")
	if err != nil {
		t.Fatalf("HashPassword() error = %v", err)
	}

	if CheckPassword("wrong-password", hash) {
		t.Error("CheckPassword() = true for the wrong password, want false")
	}
}

func TestCheckPassword_MalformedHash(t *testing.T) {
	if CheckPassword("anything", "not-a-bcrypt-hash") {
		t.Error("CheckPassword() = true for a malformed hash, want false")
	}
}
