package otel

import (
	"bytes"
	"encoding/json"
	"io"
	"mime"
	"net/http"
	"net/url"
	"os"
	"strconv"
	"strings"

	"github.com/go-chi/chi/v5/middleware"
	"go.opentelemetry.io/otel/attribute"
	"go.opentelemetry.io/otel/trace"
)

// maxRecordedBodyBytes caps how much of a body is buffered. Bodies over the cap are not recorded,
// because a truncated JSON document can't be parsed, and so can't be redacted.
const maxRecordedBodyBytes = 8 << 10

const redactedValue = "[REDACTED]"

var sensitiveBodyKeys = map[string]bool{
	"password":   true,
	"token":      true,
	"csrf":       true,
	"csrf_token": true,
}

// recordBodies reports whether QUICKPIZZA_OTEL_RECORD_BODIES is set to a truthy value.
func recordBodies() bool {
	v, ok := os.LookupEnv("QUICKPIZZA_OTEL_RECORD_BODIES")
	if !ok {
		return false
	}
	b, _ := strconv.ParseBool(v)
	return b
}

// bodyEvents adds the request and response bodies to the current server span as the
// "http.request.body" and "http.response.body" span events. It must run after otelhttp, so the
// span is already in the request context.
func bodyEvents(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		span := trace.SpanFromContext(r.Context())
		if !span.IsRecording() || r.Header.Get("Upgrade") != "" {
			next.ServeHTTP(w, r)
			return
		}

		if r.Body != nil && isTextual(r.Header.Get("Content-Type")) {
			reqBody, _ := io.ReadAll(io.LimitReader(r.Body, maxRecordedBodyBytes+1))
			r.Body = readCloser{io.MultiReader(bytes.NewReader(reqBody), r.Body), r.Body}
			addBodyEvent(span, "http.request.body", r.Header.Get("Content-Type"), reqBody, len(reqBody))
		}

		ww := middleware.NewWrapResponseWriter(w, r.ProtoMajor)
		respBody := &limitedBuffer{limit: maxRecordedBodyBytes}
		ww.Tee(respBody)

		next.ServeHTTP(ww, r)

		if contentType := ww.Header().Get("Content-Type"); isTextual(contentType) {
			addBodyEvent(span, "http.response.body", contentType, respBody.Bytes(), ww.BytesWritten())
		}
	})
}

func addBodyEvent(span trace.Span, name, contentType string, body []byte, size int) {
	if size == 0 {
		return
	}
	attrs := []attribute.KeyValue{attribute.Int("body.size", size)}
	if size > maxRecordedBodyBytes {
		attrs = append(attrs, attribute.Bool("body.truncated", true))
	} else {
		attrs = append(attrs, attribute.String("body", redactBody(contentType, body)))
	}
	span.AddEvent(name, trace.WithAttributes(attrs...))
}

func isTextual(contentType string) bool {
	mediaType, _, err := mime.ParseMediaType(contentType)
	if err != nil {
		return false
	}
	switch mediaType {
	case "application/json", "application/xml", "text/xml", "text/plain", "application/x-www-form-urlencoded":
		return true
	}
	return strings.HasSuffix(mediaType, "+json")
}

// redactBody replaces the values of sensitiveBodyKeys. A JSON body that doesn't parse is not
// recorded, because it can't be redacted.
func redactBody(contentType string, body []byte) string {
	mediaType, _, _ := mime.ParseMediaType(contentType)
	switch {
	case mediaType == "application/json" || strings.HasSuffix(mediaType, "+json"):
		var v any
		if err := json.Unmarshal(body, &v); err != nil {
			return "[unparseable JSON, not recorded]"
		}
		out, _ := json.Marshal(redactJSON(v))
		return string(out)
	case mediaType == "application/x-www-form-urlencoded":
		values, err := url.ParseQuery(string(body))
		if err != nil {
			return "[unparseable form, not recorded]"
		}
		for k := range values {
			if sensitiveBodyKeys[strings.ToLower(k)] {
				values[k] = []string{redactedValue}
			}
		}
		return values.Encode()
	}
	return string(body)
}

func redactJSON(v any) any {
	switch t := v.(type) {
	case map[string]any:
		for k, val := range t {
			if sensitiveBodyKeys[strings.ToLower(k)] {
				t[k] = redactedValue
			} else {
				t[k] = redactJSON(val)
			}
		}
	case []any:
		for i, val := range t {
			t[i] = redactJSON(val)
		}
	}
	return v
}

type readCloser struct {
	io.Reader
	io.Closer
}

// limitedBuffer keeps the first limit bytes written and discards the rest without error, so
// teeing a large response never fails the real write.
type limitedBuffer struct {
	bytes.Buffer
	limit int
}

func (b *limitedBuffer) Write(p []byte) (int, error) {
	if room := b.limit - b.Len(); room > 0 {
		if len(p) > room {
			b.Buffer.Write(p[:room])
		} else {
			b.Buffer.Write(p)
		}
	}
	return len(p), nil
}
