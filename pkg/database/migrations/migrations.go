package migrations

import (
	"github.com/grafana/quickpizza/pkg/database/migrations/catalog"
	"github.com/grafana/quickpizza/pkg/database/migrations/copy"
)

var Catalog = catalog.Migrations
var Copy = copy.Migrations
