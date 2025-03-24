package database

import (
	"context"
	"database/sql"
	"errors"
	"fmt"
	"os"
	"strconv"

	"log/slog"

	"github.com/uptrace/bun"
	"github.com/uptrace/bun/migrate"

	"github.com/grafana/quickpizza/pkg/database/migrations"
	"github.com/grafana/quickpizza/pkg/errorinjector"
	"github.com/grafana/quickpizza/pkg/model"
	"github.com/grafana/quickpizza/pkg/password"
	"github.com/grafana/quickpizza/pkg/util"
)

type Catalog struct {
	db *bun.DB

	fixedPizzas  int
	fixedUsers   int
	fixedRatings int
	maxPizzas    int
	maxUsers     int
	maxRatings   int
}

const getRatingsMax = 50

var ErrUsernameTaken = errors.New("username already taken")
var ErrGlobalOperationNotPermitted = errors.New("operation not permitted for default user")

func NewCatalog(connString string) (*Catalog, error) {
	db, err := initializeDB(connString)
	if err != nil {
		return nil, err
	}
	log := slog.With("db", "catalog")
	mig := migrate.NewMigrator(db, migrations.Catalog)
	if err := mig.Init(context.Background()); err != nil {
		return nil, err
	}
	log.Info("running migrations")
	g, err := mig.Migrate(context.Background())
	log.Info("applied migrations", "count", len(g.Migrations.Applied()))
	if err != nil {
		return nil, err
	}
	db.RegisterModel((*model.PizzaToIngredients)(nil))

	c := &Catalog{
		db:           db,
		fixedPizzas:  envInt("QUICKPIZZA_DB_FIXED_PIZZAS", 100),
		fixedUsers:   envInt("QUICKPIZZA_DB_FIXED_USERS", 10),
		fixedRatings: envInt("QUICKPIZZA_DB_FIXED_RATINGS", 10),
		maxPizzas:    envInt("QUICKPIZZA_DB_MAX_PIZZAS", 5000),
		maxUsers:     envInt("QUICKPIZZA_DB_MAX_USERS", 5000),
		maxRatings:   envInt("QUICKPIZZA_DB_MAX_RATINGS", 10000),
	}

	log.Info(
		"Catalog parameters",
		"fixedPizzas", c.fixedPizzas,
		"fixedUsers", c.fixedUsers,
		"fixedRatings", c.fixedRatings,
		"maxPizzas", c.maxPizzas,
		"maxUsers", c.maxUsers,
		"maxRatings", c.maxRatings,
	)

	return c, nil
}

func (c *Catalog) GetIngredients(ctx context.Context, t string) ([]model.Ingredient, error) {
	// Inject an artificial error for testing purposes
	err := errorinjector.InjectErrors(ctx, "get-ingredients")
	if err != nil {
		return nil, err
	}

	var ingredients []model.Ingredient
	err = c.db.NewSelect().Model(&ingredients).Where("type = ?", t).Scan(ctx)
	return ingredients, err
}

func (c *Catalog) GetDoughs(ctx context.Context) ([]model.Dough, error) {
	var doughs []model.Dough
	err := c.db.NewSelect().Model(&doughs).Scan(ctx)
	return doughs, err
}

func (c *Catalog) GetTools(ctx context.Context) ([]string, error) {
	var tools []string
	err := c.db.NewSelect().Model(&model.Tool{}).Column("name").Scan(ctx, &tools)
	return tools, err
}

func (c *Catalog) GetHistory(ctx context.Context, limit int) ([]model.Pizza, error) {
	var history []model.Pizza
	err := c.db.NewSelect().Model(&history).Relation("Dough").Relation("Ingredients").Order("created_at DESC").Limit(limit).Scan(ctx)
	return history, err
}

func (c *Catalog) GetRecommendation(ctx context.Context, id int) (*model.Pizza, error) {
	var pizza model.Pizza
	err := c.db.NewSelect().Model(&pizza).Relation("Dough").Relation("Ingredients").Where("pizza.id = ?", id).Limit(1).Scan(ctx)
	if err == sql.ErrNoRows {
		return nil, nil
	}
	return &pizza, err
}

func (c *Catalog) GetRatings(ctx context.Context, user *model.User) ([]*model.Rating, error) {
	ratings := make([]*model.Rating, 0)
	err := c.db.NewSelect().Model((*model.Rating)(nil)).Relation("User").Relation("Pizza").Where("rating.user_id = ?", user.ID).Limit(getRatingsMax).Scan(ctx, &ratings)
	if err == sql.ErrNoRows {
		return nil, nil
	}
	return ratings, err
}

func (c *Catalog) GetRating(ctx context.Context, user *model.User, ratingID int) (*model.Rating, error) {
	var rating model.Rating
	err := c.db.NewSelect().Model(&rating).Relation("User").Relation("Pizza").Where("rating.id = ? AND rating.user_id = ?", ratingID, user.ID).Limit(1).Scan(ctx)
	if err == sql.ErrNoRows {
		return nil, nil
	}
	return &rating, err
}

func (c *Catalog) DeleteRatings(ctx context.Context, user *model.User) error {
	if user.IsGlobal() {
		return ErrGlobalOperationNotPermitted
	}

	_, err := c.db.NewDelete().Model((*model.Rating)(nil)).Where("rating.user_id = ?", user.ID).Exec(ctx)
	return err
}

func (c *Catalog) DeleteRating(ctx context.Context, user *model.User, ratingID int) error {
	if user.Username == model.GlobalUsername {
		return ErrGlobalOperationNotPermitted
	}

	rating, err := c.GetRating(ctx, user, ratingID)
	if err != nil {
		return err
	} else if rating == nil {
		return fmt.Errorf("rating ID %v not found", ratingID)
	}

	_, err = c.db.NewDelete().Model(rating).WherePK().Exec(ctx)
	return err
}

func (c *Catalog) UpdateRating(ctx context.Context, user *model.User, rating *model.Rating) (*model.Rating, error) {
	if user.IsGlobal() {
		return nil, ErrGlobalOperationNotPermitted
	}

	existing, err := c.GetRating(ctx, user, int(rating.ID))
	if err != nil {
		return nil, err
	}

	if existing == nil || existing.UserID != user.ID {
		return nil, fmt.Errorf("rating ID %v not found", rating.ID)
	}

	existing.Stars = rating.Stars
	err = c.db.RunInTx(ctx, nil, func(ctx context.Context, tx bun.Tx) error {
		_, err := tx.NewUpdate().Model(existing).Column("stars").WherePK().Exec(ctx)
		return err
	})

	if err != nil {
		return nil, err
	}

	return existing, nil
}

func (c *Catalog) RecordRating(ctx context.Context, rating *model.Rating) error {
	pizza, err := c.GetRecommendation(ctx, int(rating.PizzaID))
	if err != nil {
		return err
	}

	if pizza == nil {
		return fmt.Errorf("pizza ID %v not found", rating.PizzaID)
	}

	rating.ID = 0

	return c.db.RunInTx(ctx, nil, func(ctx context.Context, tx bun.Tx) error {
		_, err := tx.NewInsert().Model(rating).Exec(ctx)
		if err != nil {
			return err
		}

		return c.enforceTableSizeLimits(ctx, tx, (*model.Rating)(nil), c.fixedRatings, c.maxRatings)
	})
}

func (c *Catalog) RecordUser(ctx context.Context, user *model.User) error {
	passwordHash, err := password.HashPassword(user.Password)
	if err != nil {
		return err
	}

	user.PasswordHash = passwordHash
	user.Token = util.GenerateAlphaNumToken(model.UserTokenLength)
	user.ID = 0

	var tmp model.User
	err = c.db.NewSelect().Model(&tmp).Where("username = ?", user.Username).Limit(1).Scan(ctx)
	if err != sql.ErrNoRows {
		if err == nil {
			return ErrUsernameTaken
		}
		return err
	}

	return c.db.RunInTx(ctx, nil, func(ctx context.Context, tx bun.Tx) error {
		_, err := tx.NewInsert().Model(user).Exec(ctx)
		if err != nil {
			return err
		}

		return c.enforceTableSizeLimits(ctx, tx, (*model.User)(nil), c.fixedUsers, c.maxUsers)
	})
}

func (c *Catalog) LoginUser(ctx context.Context, username, passwordText string) (*model.User, error) {
	var user model.User
	err := c.db.NewSelect().Model(&user).Where("username = ?", username).Limit(1).Scan(ctx)
	if err == sql.ErrNoRows {
		return nil, nil
	}

	// Some pre-created users have their password stored as plaintext.
	if user.PasswordPlaintext != "" {
		if passwordText == user.PasswordPlaintext {
			return &user, nil
		}
		return nil, nil
	}

	// Any password works for logging in as the default, global user.
	if user.IsGlobal() || password.CheckPassword(passwordText, user.PasswordHash) {
		return &user, nil
	}
	return nil, nil
}

// Authenticate finds the corresponding user for token.
// If a user is not found, then a default user is returned, with ID 1. This is done
// in order to simplify the testing/usage of QuickPizza in general. This function
// will always return a user, unless it returns a non-nil error.
func (c *Catalog) Authenticate(ctx context.Context, token string) (*model.User, error) {
	var user model.User
	err := c.db.NewSelect().Model(&user).Where("token = ?", token).Limit(1).Scan(ctx)

	if err == sql.ErrNoRows {
		// In order to support requests coming directly from the
		// index.html (which contains a randomly-generated token not
		// stored in the DB), return a global, default user if the
		// token lookup failed.
		err = c.db.NewSelect().Model(&user).Where("id = 1").Limit(1).Scan(ctx)
	}
	return &user, err
}

func (c *Catalog) RecordRecommendation(ctx context.Context, pizza *model.Pizza) error {
	// Inject an artificial error for testing purposes
	err := errorinjector.InjectErrors(ctx, "record-recommendation")
	if err != nil {
		return err
	}

	pizza.DoughID = pizza.Dough.ID
	return c.db.RunInTx(ctx, nil, func(ctx context.Context, tx bun.Tx) error {
		_, err := tx.NewInsert().Model(pizza).Exec(ctx)
		if err != nil {
			return err
		}
		for _, i := range pizza.Ingredients {
			_, err = tx.NewInsert().Model(&model.PizzaToIngredients{PizzaID: pizza.ID, IngredientID: i.ID}).Exec(ctx)
			if err != nil {
				return err
			}
		}

		return c.enforceTableSizeLimits(ctx, tx, (*model.Pizza)(nil), c.fixedPizzas, c.maxPizzas)
	})
}

// enforceTableSizeLimits limits the size of a table, which must have an ID row.
// All rows will be deleted except the N newest ones, where N == maximum.
// If fixed > 0, then the first K rows (IDs 0, 1, 2...) will never be deleted,
// where K == fixed (even if this would make the table exceed N rows).
// If maximum is 0 or negative, then do not enforce any limits.
// Useful for keeping an in-memory SQLite database size below a certain number.
func (c *Catalog) enforceTableSizeLimits(ctx context.Context, tx bun.Tx, model any, fixed, maximum int) error {
	if maximum <= 0 {
		return nil
	}
	_, err := tx.NewDelete().
		Model(model).
		Where(fmt.Sprintf("id NOT IN (?) AND id > %v", fixed), tx.NewSelect().
			Model(model).
			Order("created_at DESC").
			Column("id").
			Limit(maximum)).
		Exec(ctx)
	return err
}

func envInt(name string, defaultVal int) int {
	v, found := os.LookupEnv(name)
	if !found {
		return defaultVal
	}

	b, err := strconv.Atoi(v)
	if err != nil {
		return defaultVal
	}

	return b
}
