package main

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io/fs"
	"log"
	"math/rand"
	"net/http"
	"os"
	"strconv"
	"strings"
	"sync"
	"time"

	"github.com/go-chi/chi"
	"github.com/go-chi/chi/middleware"
	"github.com/go-chi/cors"
	"github.com/grafana/quickpizza/pkg/pizza"
	"github.com/grafana/quickpizza/pkg/web"
	"github.com/olahol/melody"
	"github.com/prometheus/client_golang/prometheus"
	"github.com/prometheus/client_golang/prometheus/promauto"
	"github.com/prometheus/client_golang/prometheus/promhttp"
	"github.com/rs/xid"
	"go.uber.org/zap"
)

var (
	pizzaRecommendations = promauto.NewCounterVec(prometheus.CounterOpts{
		Name: "pizza_recommendations_total",
		Help: "The total number of pizza recommendations",
	}, []string{"vegetarian", "tool"})

	numberOfIngredientsPerPizza = promauto.NewHistogram(prometheus.HistogramOpts{
		Name:    "number_of_ingredients_per_pizza",
		Help:    "The number of ingredients per pizza",
		Buckets: []float64{1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20},
	})

	pizzaCaloriesPerSlice = promauto.NewHistogram(prometheus.HistogramOpts{
		Name:    "pizza_calories_per_slice",
		Help:    "The number of calories per slice of pizza",
		Buckets: []float64{100, 200, 300, 400, 500, 600, 700, 800, 900, 1000, 1100, 1200, 1300, 1400, 1500, 1600, 1700, 1800, 1900, 2000},
	})

	httpRequests = promauto.NewCounterVec(prometheus.CounterOpts{
		Name: "http_requests_total",
		Help: "The total number of HTTP requests",
	}, []string{"method", "path", "status"})

	httpRequestDuration = promauto.NewHistogramVec(prometheus.HistogramOpts{
		Name: "http_request_duration_seconds",
		Help: "The duration of HTTP requests",
	}, []string{"method", "path", "status"})
)

type Data struct {
	Doughs []pizza.Dough `json:"doughs"`

	// Ingredients
	OliveOils   []pizza.Ingredient `json:"olive_oils"`
	Tomatoes    []pizza.Ingredient `json:"tomatoes"`
	Mozzarellas []pizza.Ingredient `json:"mozzarellas"`
	Toppings    []pizza.Ingredient `json:"toppings"`

	// Important stuff
	Tools []string `json:"tools"`

	// Naming
	Adjectives   []string `json:"adjectives"`
	ClassicNames []string `json:"classic_names"`

	// Quotes
	Quotes []string `json:"quotes"`
}

type InMemoryDatabase struct {
	mx                  sync.Mutex
	data                Data
	lastRecommendations []pizza.Pizza
	userSessionTokens   map[string]time.Time
}

func (db *InMemoryDatabase) GeneratePizza(restrictions pizza.Restrictions) pizza.Pizza {
	db.mx.Lock()
	defer db.mx.Unlock()

	if restrictions.MaxCaloriesPerSlice == 0 {
		restrictions.MaxCaloriesPerSlice = 1000
	}
	if restrictions.MaxNumberOfToppings == 0 {
		restrictions.MaxNumberOfToppings = 5
	}
	if restrictions.MinNumberOfToppings == 0 {
		restrictions.MinNumberOfToppings = 3
	}

	var validOliveOils []pizza.Ingredient
	for _, oliveOil := range db.data.OliveOils {
		if !contains(restrictions.ExcludedIngredients, oliveOil.Name) && (!restrictions.MustBeVegetarian || oliveOil.Vegetarian) {
			validOliveOils = append(validOliveOils, oliveOil)
		}
	}

	var validTomatoes []pizza.Ingredient
	for _, tomato := range db.data.Tomatoes {
		if !contains(restrictions.ExcludedIngredients, tomato.Name) && (!restrictions.MustBeVegetarian || tomato.Vegetarian) {
			validTomatoes = append(validTomatoes, tomato)
		}
	}

	var validMozzarellas []pizza.Ingredient
	for _, mozzarella := range db.data.Mozzarellas {
		if !contains(restrictions.ExcludedIngredients, mozzarella.Name) && (!restrictions.MustBeVegetarian || mozzarella.Vegetarian) {
			validMozzarellas = append(validMozzarellas, mozzarella)
		}
	}

	var validToppings []pizza.Ingredient
	for _, topping := range db.data.Toppings {
		if !contains(restrictions.ExcludedIngredients, topping.Name) && (!restrictions.MustBeVegetarian || topping.Vegetarian) {
			validToppings = append(validToppings, topping)
		}
	}

	var validTools []string
	for _, tool := range db.data.Tools {
		if !contains(restrictions.ExcludedTools, tool) {
			validTools = append(validTools, tool)
		}
	}

	var p pizza.Pizza
	for i := 0; i < 10; i++ {
		var randomName string
		for {
			randomName = fmt.Sprintf("%s %s", db.data.Adjectives[rand.Intn(len(db.data.Adjectives))], db.data.ClassicNames[rand.Intn(len(db.data.ClassicNames))])
			if strings.HasPrefix(randomName, "A") || strings.HasPrefix(randomName, "E") || strings.HasPrefix(randomName, "I") || strings.HasPrefix(randomName, "O") || strings.HasPrefix(randomName, "U") {
				randomName = fmt.Sprintf("An %s", randomName)
			} else {
				if rand.Intn(100) < 50 {
					randomName = fmt.Sprintf("The %s", randomName)
				} else {
					randomName = fmt.Sprintf("A %s", randomName)
				}
			}

			// Measure how funny the name is. It fails if the name is too funny or too unfunny
			if rand.Intn(100) < 50 {
				time.Sleep(time.Duration(rand.Intn(100)) * time.Millisecond)
				break
			}
		}

		p = pizza.Pizza{
			Name:        randomName,
			Dough:       db.data.Doughs[rand.Intn(len(db.data.Doughs))],
			Ingredients: []pizza.Ingredient{validOliveOils[rand.Intn(len(validOliveOils))], validTomatoes[rand.Intn(len(validTomatoes))], validMozzarellas[rand.Intn(len(validMozzarellas))]},
			Tool:        validTools[rand.Intn(len(validTools))],
		}

		for j := 0; j < rand.Intn(restrictions.MaxNumberOfToppings-restrictions.MinNumberOfToppings)+restrictions.MinNumberOfToppings; j++ {
			p.Ingredients = append(p.Ingredients, validToppings[rand.Intn(len(validToppings))])
		}

		uniqueIngredients := make(map[string]pizza.Ingredient)
		for _, ingredient := range p.Ingredients {
			uniqueIngredients[ingredient.Name] = ingredient
		}
		p.Ingredients = make([]pizza.Ingredient, 0)
		for _, ingredient := range uniqueIngredients {
			p.Ingredients = append(p.Ingredients, ingredient)
		}

		if p.CalculateCalories() > restrictions.MaxCaloriesPerSlice {
			continue
		}
		break
	}

	return p
}

func (db *InMemoryDatabase) PopulateFromFile(path string) error {
	db.mx.Lock()
	defer db.mx.Unlock()

	file, err := os.Open(path)
	if err != nil {
		return err
	}
	defer file.Close()

	decoder := json.NewDecoder(file)
	err = decoder.Decode(&db.data)
	if err != nil {
		return err
	}

	return nil
}

func (d *InMemoryDatabase) PersistToFile(path string) error {
	d.mx.Lock()
	defer d.mx.Unlock()

	file, err := os.Create(path)
	if err != nil {
		return err
	}
	defer file.Close()

	encoder := json.NewEncoder(file)
	err = encoder.Encode(&d.data)
	if err != nil {
		return err
	}

	return nil
}

func (db *InMemoryDatabase) SetLatestPizza(pizza pizza.Pizza) {
	db.mx.Lock()
	defer db.mx.Unlock()

	// TODO: Store only the last 10 pizzas
	db.lastRecommendations = append(db.lastRecommendations, pizza)
}

func contains(slice []string, value string) bool {
	for _, item := range slice {
		if item == value {
			return true
		}
	}
	return false
}

type PizzaRecommendation struct {
	Pizza      pizza.Pizza `json:"pizza"`
	Calories   int         `json:"calories"`
	Vegetarian bool        `json:"vegetarian"`
}

func main() {
	globalLogger, err := zap.NewProduction()
	if err != nil {
		panic(err)
	}

	db := InMemoryDatabase{}
	err = db.PopulateFromFile("data.json")
	if err != nil {
		globalLogger.Fatal("Failed to load database", zap.Error(err))
	}

	m := melody.New()
	r := chi.NewRouter()
	r.Use(PrometheusMiddleware)
	r.Use(middleware.Recoverer)
	r.Use(cors.New(cors.Options{
		AllowedOrigins:   []string{"*"},
		AllowedMethods:   []string{"GET", "POST", "PUT", "DELETE", "OPTIONS"},
		AllowedHeaders:   []string{"Accept", "Authorization", "Content-Type", "X-CSRF-Token", "X-User-ID"},
		ExposedHeaders:   []string{"Link"},
		AllowCredentials: true,
		MaxAge:           300, // Maximum value not ignored by any of major browsers
	}).Handler)

	go func() {
		for {
			time.Sleep(time.Minute)
			for token, creation := range db.userSessionTokens {
				if time.Since(creation) > 1*time.Hour {
					delete(db.userSessionTokens, token)
				}
			}
		}
	}()

	r.Handle("/*", SvelteKitHandler("/*"))

	r.Get("/ws", func(w http.ResponseWriter, r *http.Request) {
		m.HandleRequest(w, r)
	})

	m.HandleMessage(func(s *melody.Session, msg []byte) {
		m.Broadcast(msg)
	})

	r.Group(func(r chi.Router) {
		r.Use(ValidateUserMiddleware)
		r.Post("/api/pizza", func(w http.ResponseWriter, r *http.Request) {
			logger := loggerWithUserID(globalLogger, r)
			logger.Info("Received pizza recommendation request")
			var restrictions pizza.Restrictions

			err := json.NewDecoder(r.Body).Decode(&restrictions)
			if err != nil {
				logger.Error("Failed to decode request body", zap.Error(err))
				w.WriteHeader(http.StatusBadRequest)
				return
			}

			pizza := db.GeneratePizza(restrictions)
			db.SetLatestPizza(pizza)

			pizzaRecommendation := PizzaRecommendation{
				Pizza:      pizza,
				Calories:   pizza.CalculateCalories(),
				Vegetarian: pizza.IsVegetarian(),
			}

			pizzaRecommendations.With(prometheus.Labels{
				"vegetarian": strconv.FormatBool(pizzaRecommendation.Vegetarian),
				"tool":       pizzaRecommendation.Pizza.Tool,
			}).Inc()
			numberOfIngredientsPerPizza.Observe(float64(len(pizza.Ingredients)))
			pizzaCaloriesPerSlice.Observe(float64(pizzaRecommendation.Calories))

			logger.Info("New pizza recommendation", zap.String("user", r.Context().Value("user").(string)), zap.Any("pizza", pizzaRecommendation.Pizza.Name))

			err = json.NewEncoder(w).Encode(pizzaRecommendation)
			if err != nil {
				logger.Error("Failed to encode pizza recommendation", zap.Error(err))
				w.WriteHeader(http.StatusInternalServerError)
				return
			}
		})

		r.Get("/api/ingredients/{type}", func(w http.ResponseWriter, r *http.Request) {
			logger := loggerWithUserID(globalLogger, r)
			ingredientType := chi.URLParam(r, "type")
			isVegetarian := r.URL.Query().Get("is_vegetarian")

			var ingredients []pizza.Ingredient
			switch ingredientType {
			case "olive_oil":
				ingredients = db.data.OliveOils
			case "tomato":
				ingredients = db.data.Tomatoes
			case "mozzarella":
				ingredients = db.data.Mozzarellas
			case "topping":
				ingredients = db.data.Toppings
			default:
				w.WriteHeader(http.StatusBadRequest)
				return
			}

			var filteredIngredients []pizza.Ingredient
			for _, ingredient := range ingredients {
				if isVegetarian != "" && ingredient.Vegetarian != (isVegetarian == "true") {
					continue
				}
				filteredIngredients = append(filteredIngredients, ingredient)
			}

			logger.Info("Ingredients requested", zap.String("type", ingredientType))

			err = json.NewEncoder(w).Encode(map[string][]pizza.Ingredient{"ingredients": filteredIngredients})
			if err != nil {
				logger.Error("Failed to encode response", zap.Error(err))
				w.WriteHeader(http.StatusInternalServerError)
				return
			}
		})

		r.Get("/api/doughs", func(w http.ResponseWriter, r *http.Request) {
			logger := loggerWithUserID(globalLogger, r)
			logger.Info("Doughs requested")
			err = json.NewEncoder(w).Encode(map[string][]pizza.Dough{"doughs": db.data.Doughs})
			if err != nil {
				logger.Error("Failed to encode response", zap.Error(err))
				w.WriteHeader(http.StatusInternalServerError)
				return
			}
		})

		r.Get("/api/tools", func(w http.ResponseWriter, r *http.Request) {
			logger := loggerWithUserID(globalLogger, r)
			logger.Info("Tools requested")
			err = json.NewEncoder(w).Encode(map[string][]string{"tools": db.data.Tools})
			if err != nil {
				logger.Error("Failed to encode response", zap.Error(err))
				w.WriteHeader(http.StatusInternalServerError)
				return
			}
		})

		r.Get("/api/quotes", func(w http.ResponseWriter, r *http.Request) {
			logger := loggerWithUserID(globalLogger, r)
			logger.Info("Quotes requested")
			err = json.NewEncoder(w).Encode(map[string][]string{"quotes": db.data.Quotes})
			if err != nil {
				logger.Error("Failed to encode response", zap.Error(err))
				w.WriteHeader(http.StatusInternalServerError)
				return
			}
		})

		r.Get("/api/login", func(w http.ResponseWriter, r *http.Request) {
			logger := loggerWithUserID(globalLogger, r)
			logger.Info("Login requested")
			user := r.URL.Query().Get("user")
			password := r.URL.Query().Get("password")

			if user == "" || password == "" {
				w.WriteHeader(http.StatusBadRequest)
				return
			}

			if user != "admin" || password != "admin" {
				w.WriteHeader(http.StatusUnauthorized)
				return
			}

			guid := xid.New()
			token := guid.String()
			if db.userSessionTokens == nil {
				db.userSessionTokens = make(map[string]time.Time)
			}
			db.userSessionTokens[token] = time.Now()
			err = json.NewEncoder(w).Encode(map[string]string{"token": token})
			if err != nil {
				logger.Error("Failed to encode response", zap.Error(err))
				w.WriteHeader(http.StatusInternalServerError)
				return
			}
		})

		r.Get("/api/internal/recommendations", func(w http.ResponseWriter, r *http.Request) {
			logger := loggerWithUserID(globalLogger, r)
			logger.Info("Recommendations requested")
			token := r.Header.Get("Authorization")
			if token == "" {
				w.WriteHeader(http.StatusUnauthorized)
				return
			}

			token = strings.TrimPrefix(token, "Bearer ")
			if _, ok := db.userSessionTokens[token]; !ok {
				w.WriteHeader(http.StatusUnauthorized)
				return
			}

			err = json.NewEncoder(w).Encode(map[string][]pizza.Pizza{"pizzas": db.lastRecommendations})
			if err != nil {
				logger.Error("Failed to encode response", zap.Error(err))
				w.WriteHeader(http.StatusInternalServerError)
				return
			}
		})
	})

	r.Handle("/metrics", promhttp.Handler())

	globalLogger.Info("Starting QuickPizza. Listening on :3333")
	http.ListenAndServe(":3333", r)

}

// From: https://www.liip.ch/en/blog/embed-sveltekit-into-a-go-binary
func SvelteKitHandler(path string) http.Handler {
	fsys, err := fs.Sub(web.EmbeddedFiles, "build")
	if err != nil {
		log.Fatal(err)
	}
	filesystem := http.FS(fsys)

	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		path := strings.TrimPrefix(r.URL.Path, path)
		// try if file exists at path, if not append .html (SvelteKit adapter-static specific)
		_, err := filesystem.Open(path)
		if errors.Is(err, os.ErrNotExist) {
			path = fmt.Sprintf("%s.html", path)
		}
		r.URL.Path = path
		http.FileServer(filesystem).ServeHTTP(w, r)
	})
}

func loggerWithUserID(logger *zap.Logger, r *http.Request) *zap.Logger {
	return logger.With(zap.String("user", r.Context().Value("user").(string)))
}

func ValidateUserMiddleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		userID := r.Header.Get("X-User-ID")
		if userID == "" {
			w.WriteHeader(http.StatusUnauthorized)
			return
		}

		ctx := context.WithValue(r.Context(), "user", userID)
		next.ServeHTTP(w, r.WithContext(ctx))
	})
}

func PrometheusMiddleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		start := time.Now()
		ww := middleware.NewWrapResponseWriter(w, r.ProtoMajor)
		next.ServeHTTP(w, r)
		duration := time.Since(start)
		httpRequests.WithLabelValues(r.Method, r.URL.Path, http.StatusText(ww.Status())).Inc()
		httpRequestDuration.WithLabelValues(r.Method, r.URL.Path, http.StatusText(ww.Status())).Observe(duration.Seconds())
	})
}
