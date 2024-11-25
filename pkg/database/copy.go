package database

import (
	"context"

	"log/slog"

	"github.com/grafana/quickpizza/pkg/database/migrations"
	"github.com/grafana/quickpizza/pkg/model"

	"github.com/uptrace/bun"
	"github.com/uptrace/bun/migrate"
)

type Copy struct {
	db *bun.DB
}

func NewCopy(connString string) (*Copy, error) {
	db, err := initializeDB(connString)
	if err != nil {
		return nil, err
	}
	log := slog.With("db", "copy")
	mig := migrate.NewMigrator(db, migrations.Copy)
	if err := mig.Init(context.Background()); err != nil {
		return nil, err
	}
	log.Info("running migrations")
	g, err := mig.Migrate(context.Background())
	log.Info("applied migrations", "count", len(g.Migrations.Applied()))
	if err != nil {
		return nil, err
	}
	return &Copy{
		db: db,
	}, nil
}

func (c *Copy) GetQuotes(ctx context.Context) ([]string, error) {
	var quotes []string
	err := c.db.NewSelect().Model(&model.Quote{}).Column("name").Scan(ctx, &quotes)
	return quotes, err
}

func (c *Copy) GetAdjectives(ctx context.Context) ([]string, error) {
	var adjectives []string
	err := c.db.NewSelect().Model(&model.Adjective{}).Column("name").Scan(ctx, &adjectives)
	return adjectives, err
}

func (c *Copy) GetClassicalNames(ctx context.Context) ([]string, error) {
	var classicalNames []string
	err := c.db.NewSelect().Model(&model.ClassicalName{}).Column("name").Scan(ctx, &classicalNames)
	return classicalNames, err
}
