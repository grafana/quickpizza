package http

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net/http"

	"github.com/grafana/quickpizza/pkg/errorinjector"
	"github.com/grafana/quickpizza/pkg/model"
)

var errNotFound = errors.New("Entity not found")

// httpClient is a convenience wrapper for an HTTP client that GETs and POSTs JSON requests with QuickPizza-specifics.
type httpClient struct {
	client *http.Client
}

// getJSON queries the specified URL, expecting a JSON response which gets unmarshalled in dest.
// If present in parentCtx, trace id and QuickPizza user id are propagated in the request.
// parentCtx may not be nil.
func (hc httpClient) getJSON(parentCtx context.Context, url string, dest any) error {
	request, err := http.NewRequestWithContext(parentCtx, http.MethodGet, url, nil)
	if err != nil {
		return fmt.Errorf("building http request: %w", err)
	}

	request.Header.Add("Content-Type", "application/json")

	errorinjector.AddErrorHeaders(parentCtx, request)

	resp, err := hc.do(request)
	if err != nil {
		return err
	}

	defer func() {
		_, _ = io.Copy(io.Discard, resp.Body)
		_ = resp.Body.Close()
	}()

	if resp.StatusCode == http.StatusNotFound {
		return errNotFound
	} else if resp.StatusCode != http.StatusOK {
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

// postJSON performs an HTTP POST request, marshalling src into the request body.
// If present in parentCtx, trace id and QuickPizza user id are propagated in the request.
// parentCtx may not be nil.
func (hc httpClient) postJSON(parentCtx context.Context, url string, src any, dest any) error {
	buf := &bytes.Buffer{}
	if src != nil {
		enc := json.NewEncoder(buf).Encode(src)
		if enc != nil {
			return fmt.Errorf("encoding request: %w", enc)
		}
	}

	request, err := http.NewRequestWithContext(parentCtx, http.MethodPost, url, buf)
	if err != nil {
		return fmt.Errorf("building http request: %w", err)
	}

	errorinjector.AddErrorHeaders(parentCtx, request)

	resp, err := hc.do(request)
	if err != nil {
		return fmt.Errorf("making http request: %w", err)
	}

	defer func() {
		// Close body even if we do not care about it. This allows connection reuse but, more importantly, will cause
		// the client trace to actually be sent, which wouldn't if the body is never read.
		_, _ = io.Copy(io.Discard, resp.Body)
		_ = resp.Body.Close()
	}()

	if resp.StatusCode != http.StatusCreated && resp.StatusCode != http.StatusOK {
		return fmt.Errorf("unexpected status code %d", resp.StatusCode)
	}

	if dest != nil {
		err = json.NewDecoder(resp.Body).Decode(dest)
		if err != nil {
			return err
		}
	}

	return nil
}

// do performs the supplied request.
// The supplied request is expected to include on its context the k6 user.
func (hc httpClient) do(request *http.Request) (*http.Response, error) {
	// Authenticate request with the super-secret internal token.
	request.Header.Add("X-Is-Internal", "1")

	// Propagate Authorization if present in request context.
	if auth, ok := request.Context().Value(authKey).(string); ok {
		request.Header.Add("Authorization", auth)
	}

	return hc.client.Do(request)
}

// CatalogClient is a client that queries the Catalog service.
type CatalogClient struct {
	catalogUrl string
	ctx        context.Context
	client     httpClient
}

// NewCatalogClient returns a ready-to-use client for the QuickPizza catalog, service given its URL.
func NewCatalogClient(url string) CatalogClient {
	return CatalogClient{
		catalogUrl: url,
		ctx:        context.Background(),
		client:     httpClient{client: http.DefaultClient},
	}
}

// WithClient returns a CatalogClient that uses the specified http.Client, instead of http.DefaultClient.
func (c CatalogClient) WithClient(client *http.Client) CatalogClient {
	c.client = httpClient{client: client}
	return c
}

// WithRequestContext returns a copy of the CatalogClient that will use the supplied context.
// This context should come from a http.Request, and if provided, CatalogClient will:
// - Extract parent tracer and trace IDs from it and propagate it to the requests it makes.
// - Extract the QuickPizza user ID from it and propagate it as well.
func (c CatalogClient) WithRequestContext(ctx context.Context) CatalogClient {
	c.ctx = ctx
	return c
}

func (c CatalogClient) Ingredients(ingredientType string) ([]model.Ingredient, error) {
	var ingredients struct {
		Ingredients []model.Ingredient
	}

	url := c.catalogUrl + "/api/ingredients/" + ingredientType
	err := c.client.getJSON(c.ctx, url, &ingredients)
	if err != nil {
		return nil, fmt.Errorf("querying %s: %w", url, err)
	}

	return ingredients.Ingredients, nil
}

func (c CatalogClient) Tools() ([]string, error) {
	var tools struct {
		Tools []string
	}
	url := c.catalogUrl + "/api/tools"
	err := c.client.getJSON(c.ctx, url, &tools)
	if err != nil {
		return nil, fmt.Errorf("querying %s: %w", url, err)
	}

	return tools.Tools, nil
}

func (c CatalogClient) Doughs() ([]model.Dough, error) {
	var doughs struct {
		Doughs []model.Dough
	}
	url := c.catalogUrl + "/api/doughs"
	err := c.client.getJSON(c.ctx, url, &doughs)
	if err != nil {
		return nil, fmt.Errorf("querying %s: %w", url, err)
	}

	return doughs.Doughs, nil
}

func (c CatalogClient) GetRecommendation(id int) (*model.Pizza, error) {
	result := model.Pizza{}
	err := c.client.getJSON(c.ctx, c.catalogUrl+"/api/internal/recommendations/"+fmt.Sprint(id), &result)
	if err == errNotFound {
		return nil, nil
	} else if err != nil {
		return nil, err
	}

	return &result, nil
}

func (c CatalogClient) RecordRecommendation(p model.Pizza) (*model.Pizza, error) {
	result := model.Pizza{}
	err := c.client.postJSON(c.ctx, c.catalogUrl+"/api/internal/recommendations", p, &result)
	if err != nil {
		return nil, err
	}

	return &result, nil
}

// Authenticate authenticates the token against the /api/users/token/authenticate endpoint.
// The token will be taken from the authentication information in c.ctx, under the authKey
// key. Its value should be "token <TOKEN>".
func (c CatalogClient) Authenticate() (*model.User, error) {
	result := model.User{}
	err := c.client.postJSON(c.ctx, c.catalogUrl+"/api/users/token/authenticate", nil, &result)
	if err != nil {
		return nil, err
	}
	return &result, err
}

// CopyClient is a client that queries the Copy service.
type CopyClient struct {
	copyURL string
	ctx     context.Context
	client  httpClient
}

// NewCopyClient is the Copy service equivalent of NewCatalogClient.
func NewCopyClient(url string) CopyClient {
	return CopyClient{
		copyURL: url,
		ctx:     context.Background(),
		client:  httpClient{client: http.DefaultClient},
	}
}

// WithClient is the Copy service equivalent of CatalogClient.
func (c CopyClient) WithClient(client *http.Client) CopyClient {
	c.client = httpClient{client: client}
	return c
}

// WithRequestContext is the Copy service equivalent of CatalogClient.
func (c CopyClient) WithRequestContext(ctx context.Context) CopyClient {
	c.ctx = ctx
	return c
}

func (c CopyClient) Adjectives() ([]string, error) {
	var adjs struct {
		Adjectives []string
	}

	url := c.copyURL + "/api/adjectives"
	err := c.client.getJSON(c.ctx, url, &adjs)
	if err != nil {
		return nil, fmt.Errorf("querying %s: %w", url, err)
	}

	return adjs.Adjectives, nil
}

func (c CopyClient) Names() ([]string, error) {
	var names struct {
		Names []string
	}

	url := c.copyURL + "/api/names"
	err := c.client.getJSON(c.ctx, url, &names)
	if err != nil {
		return nil, fmt.Errorf("querying %s: %w", url, err)
	}

	return names.Names, nil
}
