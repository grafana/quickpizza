package otel

import (
	"context"
	"io"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"go.opentelemetry.io/otel/attribute"
	sdktrace "go.opentelemetry.io/otel/sdk/trace"
)

type memoryExporter struct {
	spans []sdktrace.ReadOnlySpan
}

func (e *memoryExporter) ExportSpans(_ context.Context, spans []sdktrace.ReadOnlySpan) error {
	e.spans = append(e.spans, spans...)
	return nil
}

func (e *memoryExporter) Shutdown(context.Context) error { return nil }

// serveWithSpan runs h behind bodyEvents inside a recording span and returns the span's events,
// keyed by event name.
func serveWithSpan(t *testing.T, h http.Handler, req *http.Request) (map[string]map[attribute.Key]attribute.Value, *httptest.ResponseRecorder) {
	t.Helper()
	exporter := &memoryExporter{}
	tp := sdktrace.NewTracerProvider(sdktrace.WithSyncer(exporter))

	ctx, span := tp.Tracer("test").Start(req.Context(), "server")
	rec := httptest.NewRecorder()
	bodyEvents(h).ServeHTTP(rec, req.WithContext(ctx))
	span.End()

	if len(exporter.spans) != 1 {
		t.Fatalf("exported %d spans, want 1", len(exporter.spans))
	}
	events := map[string]map[attribute.Key]attribute.Value{}
	for _, ev := range exporter.spans[0].Events() {
		attrs := map[attribute.Key]attribute.Value{}
		for _, a := range ev.Attributes {
			attrs[a.Key] = a.Value
		}
		events[ev.Name] = attrs
	}
	return events, rec
}

func TestBodyEventsRecordsAndRedacts(t *testing.T) {
	var gotBody string
	h := http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		b, _ := io.ReadAll(r.Body)
		gotBody = string(b)
		w.Header().Set("Content-Type", "application/json")
		_, _ = w.Write([]byte(`{"token":"abc123","user":{"name":"ben"}}`))
	})

	reqBody := `{"username":"ben","password":"hunter2","csrf":"xyz"}`
	req := httptest.NewRequest(http.MethodPost, "/api/users/token/login", strings.NewReader(reqBody))
	req.Header.Set("Content-Type", "application/json")

	events, rec := serveWithSpan(t, h, req)

	if gotBody != reqBody {
		t.Errorf("handler read body %q, want %q", gotBody, reqBody)
	}
	if got := rec.Body.String(); got != `{"token":"abc123","user":{"name":"ben"}}` {
		t.Errorf("client got response %q, want it unchanged", got)
	}

	reqEvent := events["http.request.body"]["body"].AsString()
	if strings.Contains(reqEvent, "hunter2") || strings.Contains(reqEvent, "xyz") {
		t.Errorf("request event leaked a secret: %s", reqEvent)
	}
	if !strings.Contains(reqEvent, `"username":"ben"`) {
		t.Errorf("request event lost a non-secret field: %s", reqEvent)
	}

	respEvent := events["http.response.body"]["body"].AsString()
	if strings.Contains(respEvent, "abc123") {
		t.Errorf("response event leaked the token: %s", respEvent)
	}
	if !strings.Contains(respEvent, `"name":"ben"`) {
		t.Errorf("response event lost a nested field: %s", respEvent)
	}
}

func TestBodyEventsSkipsOversizedBody(t *testing.T) {
	big := `{"password":"hunter2","pad":"` + strings.Repeat("x", maxRecordedBodyBytes) + `"}`
	h := http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		_, _ = w.Write([]byte(big))
	})

	events, rec := serveWithSpan(t, h, httptest.NewRequest(http.MethodGet, "/api/big", nil))

	if rec.Body.Len() != len(big) {
		t.Errorf("client got %d bytes, want %d", rec.Body.Len(), len(big))
	}
	resp := events["http.response.body"]
	if _, ok := resp["body"]; ok {
		t.Error("oversized body was recorded; it can't be redacted, so it must be skipped")
	}
	if !resp["body.truncated"].AsBool() {
		t.Error("oversized body should set body.truncated")
	}
	if got := resp["body.size"].AsInt64(); got != int64(len(big)) {
		t.Errorf("body.size = %d, want %d", got, len(big))
	}
}

func TestBodyEventsSkipsNonTextual(t *testing.T) {
	h := http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "text/html; charset=utf-8")
		_, _ = w.Write([]byte("<html></html>"))
	})

	events, _ := serveWithSpan(t, h, httptest.NewRequest(http.MethodGet, "/", nil))

	if len(events) != 0 {
		t.Errorf("got events %v, want none for an HTML page with no request body", events)
	}
}
