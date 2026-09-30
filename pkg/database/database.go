package database

import (
	"database/sql"
	"fmt"
	"os"
	"runtime"
	"strings"

	"log/slog"

	"github.com/grafana/quickpizza/pkg/logging"
	"github.com/grafana/quickpizza/pkg/otel"
	"github.com/uptrace/bun"
	"github.com/uptrace/bun/dialect/pgdialect"
	"github.com/uptrace/bun/dialect/sqlitedialect"
	"github.com/uptrace/bun/driver/pgdriver"
	"github.com/uptrace/bun/driver/sqliteshim"
	"github.com/uptrace/bun/extra/bunotel"
)

// initializeDB opens the database connection and registers query hooks. The slog logging
// hook is unconditional; it isn't part of the OTel/OBI split. The bunotel OTel query hook is
// added unless otel.InstrumentDatabase() reports false (i.e. "obi" mode) AND the connection
// is Postgres - OBI only captures database queries by sniffing the Postgres wire protocol
// (see its own doc comment), so it has no way to observe SQLite, which never goes over a
// socket. Suppressing the app's own hook for SQLite too would leave the in-memory-SQLite
// default (envDBConnString in cmd/main.go) with no database spans at all in "obi" mode.
func initializeDB(connString string) (*bun.DB, error) {
	var db *bun.DB
	isPostgres := strings.HasPrefix(connString, "postgres://")
	if isPostgres {
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
	if !isPostgres || otel.InstrumentDatabase() {
		db.AddQueryHook(bunotel.NewQueryHook(
			bunotel.WithFormattedQueries(true),
			bunotel.WithDBName(dbName),
		))
	}
	return db, nil
}
