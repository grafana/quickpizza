package http

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"

	"github.com/grafana/quickpizza/pkg/pizza"
	"go.opentelemetry.io/contrib/instrumentation/net/http/otelhttp"
	"go.opentelemetry.io/otel/propagation"
	"go.opentelemetry.io/otel/trace"
)

type CatalogClient struct {
	CatalogUrl     string
	TracerProvider trace.TracerProvider
	Ctx            context.Context
}

// WithRequestContext returns a copy of the CatalogClient that will use the supplied context.
// This context should come from a http.Request, and if provided, CatalogClient will:
// - Extract parent trace IDs from it and propagate it to the requests it makes.
// - Extract the QuickPizza user ID from it and propagate it as well.
func (c CatalogClient) WithRequestContext(ctx context.Context) CatalogClient {
	c.Ctx = ctx
	return c
}

func (c CatalogClient) Ingredients(ingredientType string) ([]pizza.Ingredient, error) {
	var ingredients struct {
		Ingredients []pizza.Ingredient
	}

	url := c.CatalogUrl + "/api/ingredients/" + ingredientType
	err := getJSON(c.Ctx, url, &ingredients)
	if err != nil {
		return nil, fmt.Errorf("querying %s: %w", url, err)
	}

	return ingredients.Ingredients, nil
}

func (c CatalogClient) Tools() ([]string, error) {
	var tools struct {
		Tools []string
	}
	url := c.CatalogUrl + "/api/tools"
	err := getJSON(c.Ctx, url, &tools)
	if err != nil {
		return nil, fmt.Errorf("querying %s: %w", url, err)
	}

	return tools.Tools, nil
}

func (c CatalogClient) Doughs() ([]pizza.Dough, error) {
	var doughs struct {
		Doughs []pizza.Dough
	}
	url := c.CatalogUrl + "/api/doughs"
	err := getJSON(c.Ctx, url, &doughs)
	if err != nil {
		return nil, fmt.Errorf("querying %s: %w", url, err)
	}

	return doughs.Doughs, nil
}

func (c CatalogClient) RecordRecommendation(p pizza.Pizza) error {
	return postJSON(c.Ctx, c.CatalogUrl+"/api/internal/recommendations", p)
}

type CopyClient struct {
	CopyURL string
	Ctx     context.Context
}

func (c CopyClient) WithRequestContext(ctx context.Context) CopyClient {
	c.Ctx = ctx
	return c
}

func (c CopyClient) Adjectives() ([]string, error) {
	var adjs struct {
		Adjectives []string
	}

	url := c.CopyURL + "/api/adjectives"
	err := getJSON(c.Ctx, url, &adjs)
	if err != nil {
		return nil, fmt.Errorf("querying %s: %w", url, err)
	}

	return adjs.Adjectives, nil
}

func (c CopyClient) Names() ([]string, error) {
	var names struct {
		Names []string
	}

	url := c.CopyURL + "/api/names"
	err := getJSON(c.Ctx, url, &names)
	if err != nil {
		return nil, fmt.Errorf("querying %s: %w", url, err)
	}

	return names.Names, nil
}

// getJSON performs an HTTP GET request to the specified URL and unmarshals the JSON-encoded body in dest.
// If non-nil, user ID and trace IDs are sourced form rContext and propagated in the request.
func getJSON(parentCtx context.Context, url string, dest any) error {
	if parentCtx == nil {
		parentCtx = context.TODO()
	}

	request, err := http.NewRequestWithContext(parentCtx, http.MethodGet, url, nil)
	if err != nil {
		return fmt.Errorf("building http request: %w", err)
	}

	request.Header.Add("Content-Type", "application/json")
	resp, err := httpDoWithTracing(parentCtx, request)
	if err != nil {
		return err
	}

	defer func() {
		_, _ = io.Copy(io.Discard, resp.Body)
		_ = resp.Body.Close()
	}()

	if resp.StatusCode != http.StatusOK {
		return fmt.Errorf("unexpected status code %d", resp.StatusCode)
	}

	dec := json.NewDecoder(resp.Body)
	dec.DisallowUnknownFields()
	err = dec.Decode(dest)
	if err != nil {
		return fmt.Errorf("reading response body into target: %w", err)
	}

	return nil
}

// getJSON performs an HTTP GET request to the specified URL and unmarshals the JSON-encoded body in dest.
// If non-nil, user ID and trace IDs are sourced form rContext and propagated in the request.
func postJSON(parentCtx context.Context, url string, src any) error {
	if parentCtx == nil {
		parentCtx = context.TODO()
	}

	buf := &bytes.Buffer{}
	enc := json.NewEncoder(buf).Encode(src)
	if enc != nil {
		return fmt.Errorf("encoding request: %w", enc)
	}

	request, err := http.NewRequestWithContext(parentCtx, http.MethodPost, url, buf)
	if err != nil {
		return fmt.Errorf("building http request: %w", err)
	}

	resp, err := httpDoWithTracing(parentCtx, request)
	defer func() {
		// Close body even if we do not care about it. This allows connection reuse but, more importantly, will cause
		// the client trace to actually be sent, which wouldn't if the body is never read.
		_, _ = io.Copy(io.Discard, resp.Body)
		_ = resp.Body.Close()
	}()

	if resp.StatusCode != http.StatusCreated {
		return fmt.Errorf("unexpected status code %d", resp.StatusCode)
	}

	return err
}

func httpDoWithTracing(rContext context.Context, request *http.Request) (*http.Response, error) {
	// Authenticate request with the super-secret internal token.
	request.Header.Add("X-Internal-Token", "secret")

	if user, ok := rContext.Value("user").(string); ok {
		request.Header.Add("X-User-ID", user)
	}

	client := &http.Client{
		Transport: otelhttp.NewTransport(
			nil,
			// Propagator will retrieve the tracer used in the server from memory.
			otelhttp.WithPropagators(propagation.TraceContext{}),
		),
	}

	return client.Do(request)
}
