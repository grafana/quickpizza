package database

import (
	"database/sql"
	"fmt"
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

func initializeDB(connString string) (*bun.DB, error) {
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
	db.AddQueryHook(logging.NewBunSlogHook(slog.Default()))
	db.AddQueryHook(bunotel.NewQueryHook(
		bunotel.WithFormattedQueries(true),
	))
	return db, nil
}
