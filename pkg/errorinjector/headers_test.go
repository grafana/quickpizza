package errorinjector

import (
	"context"
	"net/http"
	"net/http/httptest"
	"testing"
)

func TestAddErrorHeaders(t *testing.T) {
	ctx := context.WithValue(context.Background(), "x-error-get-ingredients", "true")
	ctx = context.WithValue(ctx, "x-delay-get-ingredients", "500ms")

	req := httptest.NewRequest(http.MethodPost, "/api/pizza", nil)
	AddErrorHeaders(ctx, req)

	if got := req.Header.Get("x-error-get-ingredients"); got != "true" {
		t.Errorf("x-error-get-ingredients = %q, want %q", got, "true")
	}
	if got := req.Header.Get("x-delay-get-ingredients"); got != "500ms" {
		t.Errorf("x-delay-get-ingredients = %q, want %q", got, "500ms")
	}
	// Headers never set on the context should not be added to the request at all.
	if got := req.Header.Get("x-error-record-recommendation"); got != "" {
		t.Errorf("x-error-record-recommendation = %q, want unset", got)
	}
	if _, ok := req.Header["X-Error-Record-Recommendation"]; ok {
		t.Error("x-error-record-recommendation header should not be present on the request")
	}
}

func TestInjectErrorHeadersMiddleware(t *testing.T) {
	var gotFromCtx string

	next := http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if v, ok := r.Context().Value("x-error-get-ingredients").(string); ok {
			gotFromCtx = v
		}
		w.WriteHeader(http.StatusOK)
	})

	req := httptest.NewRequest(http.MethodPost, "/api/pizza", nil)
	req.Header.Set("x-error-get-ingredients", "true")

	rec := httptest.NewRecorder()
	InjectErrorHeadersMiddleware(next).ServeHTTP(rec, req)

	if gotFromCtx != "true" {
		t.Errorf("context value for x-error-get-ingredients = %q, want %q", gotFromCtx, "true")
	}
	if rec.Code != http.StatusOK {
		t.Errorf("status = %d, want %d", rec.Code, http.StatusOK)
	}
}
