package database

import (
	"database/sql"
	"fmt"
	"strings"

	"github.com/grafana/quickpizza/pkg/logging"
	"github.com/uptrace/bun"
	"github.com/uptrace/bun/dialect/pgdialect"
	"github.com/uptrace/bun/dialect/sqlitedialect"
	"github.com/uptrace/bun/driver/pgdriver"
	"github.com/uptrace/bun/driver/sqliteshim"
	"github.com/uptrace/bun/extra/bunotel"
	"golang.org/x/exp/slog"
)

func initializeDB(connString string) (*bun.DB, error) {
	var db *bun.DB
	if strings.HasPrefix(connString, "postgres://") {
		sqldb := sql.OpenDB(pgdriver.NewConnector(pgdriver.WithDSN(connString)))
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
