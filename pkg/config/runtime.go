package config

import (
	"context"
	"os"
	"strconv"

	"github.com/grafana/quickpizza/pkg/client"
	"github.com/grafana/quickpizza/pkg/database"
)

const (
	ENV_SERVICE_ALL             = "QUICKPIZZA_ALL_SERVICES"
	ENV_SERVICE_CATALOG         = "QUICKPIZZA_CATALOG"
	ENV_SERVICE_COPY            = "QUICKPIZZA_COPY"
	ENV_SERVICE_WS              = "QUICKPIZZA_WS"
	ENV_SERVICE_FRONTEND        = "QUICKPIZZA_FRONTEND"
	ENV_SERVICE_RECOMMENDATIONS = "QUICKPIZZA_RECOMMENDATIONS"
)

// Runtime exposes functions that allow the QuickPizza backend to configure itself in runtime from env vars.
type Runtime struct{}

// ServeAll returns whether all services should be enabled.
func (r Runtime) ServeAll() bool {
	allSvcs, present := os.LookupEnv(ENV_SERVICE_ALL)
	allSvcsB, _ := strconv.ParseBool(allSvcs)

	// If QUICKPIZZA_ALL_SERVICES is not defined (default), serve everything.
	if !present {
		return true
	}

	// Otherwise, serve all if QUICKPIZZA_ALL_SERVICES is truthy.
	return allSvcsB
}

// Serve returns whether a service should be enabled.
func (r Runtime) Serve(envName string) bool {
	return r.ServeAll() || r.envBool(envName)
}

func (r Runtime) CatalogClient(db *database.InMemoryDatabase) client.Catalog {
	if r.Serve(ENV_SERVICE_CATALOG) {
		return client.CatalogDB{Database: db}
	}

	return client.CatalogHTTP{CatalogUrl: r.Endpoint(ENV_SERVICE_CATALOG), Ctx: context.Background()}
}

func (r Runtime) CopyClient(db *database.InMemoryDatabase) client.Copy {
	if r.Serve(ENV_SERVICE_COPY) {
		return client.CopyDB{Database: db}
	}

	return client.CopyHTTP{CopyURL: r.Endpoint(ENV_SERVICE_COPY), Ctx: context.Background()}
}

// Endpoint returns the endpoint for a given service. If the service is enabled in this instance, it returns
// `localhost`. If it isn't, it returns the value of QUICKPIZZA_SERVICENAME_ENDPOINT.
func (r Runtime) Endpoint(envName string) string {
	endpoint, _ := os.LookupEnv(envName + "_ENDPOINT")
	return endpoint
}

// envBool returns true if an env var is set and has a truthy value.
func (r Runtime) envBool(envName string) bool {
	v, found := os.LookupEnv(envName)
	if !found {
		return false
	}

	b, err := strconv.ParseBool(v)
	if err != nil {
		return false
	}

	return b
}
