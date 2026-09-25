package database

import (
	"database/sql"
	"fmt"
	"os"
	"runtime"
	"strings"

	"log/slog"

	"github.com/grafana/quickpizza/pkg/logging"
	"github.com/uptrace/bun"
	"github.com/uptrace/bun/dialect/pgdialect"
	"github.com/uptrace/bun/dialect/sqlitedialect"
	"github.com/uptrace/bun/driver/pgdriver"
	"github.com/uptrace/bun/driver/sqliteshim"
	"github.com/uptrace/bun/extra/bunotel"
)

// initializeDB opens the database connection and registers query hooks. enableOTelSpanQueryHook
// controls whether the bunotel OTel query hook is added - callers pass
// qphttp.InstrumentDatabase() (false in "obi" mode, see its doc comment for why). The
// slog logging hook is unconditional; it isn't part of the OTel/OBI split.
func initializeDB(connString string, enableOTelSpanQueryHook bool) (*bun.DB, error) {
	var db *bun.DB
	if strings.HasPrefix(connString, "postgres://") {
		sqldb := sql.OpenDB(pgdriver.NewConnector(pgdriver.WithDSN(connString)))
		maxOpenConns := 4 * runtime.GOMAXPROCS(0)
		sqldb.SetMaxOpenConns(maxOpenConns)
		sqldb.SetMaxIdleConns(maxOpenConns)
		err := sqldb.Ping()
		if err != nil {
			return nil, fmt.Errorf("connecting to postgresql: %w", err)
		}
		db = bun.NewDB(sqldb, pgdialect.New())
	} else {
		sqldb, err := sql.Open(sqliteshim.ShimName, connString)
		if err != nil {
			return nil, err
		}
		db = bun.NewDB(sqldb, sqlitedialect.New())
		_, err = db.Exec("PRAGMA foreign_keys = ON")
		if err != nil {
			return nil, err
		}
	}
	dbName, ok := os.LookupEnv("QUICKPIZZA_OTEL_DB_NAME")
	if !ok {
		dbName = "quickpizza-database"
	}
	db.AddQueryHook(logging.NewBunSlogHook(slog.Default()))
	if enableOTelSpanQueryHook {
		db.AddQueryHook(bunotel.NewQueryHook(
			bunotel.WithFormattedQueries(true),
			bunotel.WithDBName(dbName),
		))
	}
	return db, nil
}
