package http

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io/fs"
	"log"
	"math/rand"
	"net/http"
	"net/http/httputil"
	"net/url"
	"os"
	"strconv"
	"strings"
	"time"

	"github.com/go-chi/chi"
	"github.com/go-chi/chi/middleware"
	"github.com/go-chi/cors"
	"github.com/olahol/melody"
	"github.com/prometheus/client_golang/prometheus"
	"github.com/prometheus/client_golang/prometheus/promauto"
	"github.com/prometheus/client_golang/prometheus/promhttp"
	"github.com/rs/xid"
	"go.opentelemetry.io/contrib/instrumentation/net/http/otelhttp"
	"go.opentelemetry.io/otel/propagation"
	"go.opentelemetry.io/otel/trace"
	"golang.org/x/exp/slog"

	k6 "github.com/grafana/pyroscope-go/x/k6"
	"github.com/grafana/quickpizza/pkg/database"
	"github.com/grafana/quickpizza/pkg/errorinjector"
	"github.com/grafana/quickpizza/pkg/logging"
	"github.com/grafana/quickpizza/pkg/model"
	"github.com/grafana/quickpizza/pkg/web"
)

// Variables storing prometheus metrics.
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

// PizzaRecommendation is the object returned by the /api/pizza endpoint.
type PizzaRecommendation struct {
	Pizza      model.Pizza `json:"pizza"`
	Calories   int         `json:"calories"`
	Vegetarian bool        `json:"vegetarian"`
}

// Restrictions are sent by the client to further specify how the target pizza should look like
type Restrictions struct {
	MaxCaloriesPerSlice int      `json:"maxCaloriesPerSlice"`
	MustBeVegetarian    bool     `json:"mustBeVegetarian"`
	ExcludedIngredients []string `json:"excludedIngredients"`
	ExcludedTools       []string `json:"excludedTools"`
	MaxNumberOfToppings int      `json:"maxNumberOfToppings"`
	MinNumberOfToppings int      `json:"minNumberOfToppings"`
}

func (r Restrictions) WithDefaults() Restrictions {
	if r.MaxCaloriesPerSlice == 0 {
		r.MaxCaloriesPerSlice = 1000
	}
	if r.MaxNumberOfToppings == 0 {
		r.MaxNumberOfToppings = 5
	}
	if r.MinNumberOfToppings == 0 {
		r.MinNumberOfToppings = 3
	}

	return r
}

// Server is the object that handles HTTP requests and computes pizza recommendations.
// Routes are divided into serveral groups that can be instantiated independently as microservices, or all together
// as one single big service.
type Server struct {
	log            *slog.Logger
	traceInstaller *TraceInstaller
	router         chi.Router
	melody         *melody.Melody
}

func NewServer() (*Server, error) {
	logger := slog.New(logging.NewContextLogger(slog.Default().Handler()))

	router := chi.NewRouter()
	router.Use(middleware.Recoverer)
	router.Use(cors.New(cors.Options{
		AllowedOrigins:   []string{"*"},
		AllowedMethods:   []string{"GET", "POST", "PUT", "DELETE", "OPTIONS"},
		AllowedHeaders:   []string{"Accept", "Authorization", "Content-Type", "X-CSRF-Token", "X-User-ID"},
		ExposedHeaders:   []string{"Link"},
		AllowCredentials: true,
		MaxAge:           300, // Maximum value not ignored by any of major browsers
	}).Handler)

	return &Server{
		traceInstaller: &TraceInstaller{},
		router:         router,
		melody:         melody.New(),
		log:            logger,
	}, nil
}

func (s *Server) ServeHTTP(rw http.ResponseWriter, r *http.Request) {
	s.router.ServeHTTP(rw, r)
}

// WithPrometheus adds a /metrics endpoint and instrument subsequently enabled groups with general http-level metrics.
func (s *Server) WithPrometheus() *Server {
	// Add MW with .With instead of .Use, as .Use does not allow registering MWs after routes.
	s.router = s.router.With(PrometheusMiddleware)
	s.router.Handle("/metrics", promhttp.Handler())

	return s
}

// WithProfiling adds a middleware that extracts k6 labels from the baggage and adds them to the context.
func (s *Server) WithProfiling() *Server {
	s.router = s.router.With(k6.LabelsFromBaggageHandler)

	return s
}

// WithTracing registers the specified TracerProvider within the Server.
// Subsequent handlers can use s.trace to create more detailed traces than what it would be possible if we
// applied the same tracing middleware to the whole server.
func (s *Server) WithTraceInstaller(ti *TraceInstaller) *Server {
	s.traceInstaller = ti

	return s
}

// WithFrontend enables serving the embedded Svelte frontend.
func (s *Server) WithFrontend() *Server {
	s.router.Group(func(r chi.Router) {
		s.traceInstaller.Install(r, "frontend",
			// The frontend serves a lot of static files on different paths. To save on cardinality, we override the
			// default SpanNameFormatter with one that does not include the request path in the span name.
			otelhttp.WithSpanNameFormatter(func(_ string, _ *http.Request) string {
				return "static"
			}),
		)

		r.Handle("/*", SvelteKitHandler("/*"))
	})

	return s
}

// WithConfig enables serving the config server.
func (s *Server) WithConfig(config map[string]string) *Server {
	s.router.Group(func(r chi.Router) {
		s.traceInstaller.Install(r, "config")

		r.Get("/api/config", func(rw http.ResponseWriter, r *http.Request) {
			rw.Header().Set("content-type", "application/json")

			err := json.NewEncoder(rw).Encode(config)
			if err != nil {
				s.log.ErrorContext(r.Context(), "serving config JSON", "err", err)
			}
		})
	})

	return s
}

// WithGateway enables a gateway that routes external requests to the respective services.
// This endpoint should be typically enabled toget with WithFrontend on a microservices-based deployment.
// TODO: So far the gateway only handles a few endpoints.
func (s *Server) WithGateway(catalogUrl, copyUrl, wsUrl, recommendationsUrl, configUrl string) *Server {
	s.router.Group(func(r chi.Router) {
		s.traceInstaller.Install(r, "gateway")

		// Generate client traces for requests proxied by the gateway.
		otelTransport := otelhttp.NewTransport(
			nil,
			// Propagator will retrieve the tracer used in the server from memory.
			otelhttp.WithPropagators(propagation.TraceContext{}),
		)

		r.Handle("/api/*", &httputil.ReverseProxy{
			Transport: otelTransport,
			Rewrite: func(request *httputil.ProxyRequest) {
				var u *url.URL
				switch request.In.URL.Path {
				case "/api/quotes":
					u, _ = url.Parse(copyUrl)
				case "/api/tools":
					u, _ = url.Parse(catalogUrl)
				case "/api/pizza":
					u, _ = url.Parse(recommendationsUrl)
				case "/api/config":
					u, _ = url.Parse(configUrl)
				}

				request.SetURL(u)
				s.log.InfoContext(request.In.Context(), "Proxying request", "url", request.Out.URL.String())

				// Mark outgoing requests as internal so trace context is trusted.
				request.Out.Header.Add("X-Is-Internal", "1")
			},
		})

		r.Handle("/ws", &httputil.ReverseProxy{
			Transport: otelTransport,
			Rewrite: func(request *httputil.ProxyRequest) {
				u, _ := url.Parse(wsUrl)
				request.SetURL(u)
			},
		})
	})

	return s
}

// WithWS enables serving and handle websockets.
func (s *Server) WithWS() *Server {
	// TODO: Add tracing for websockets.
	s.router.Get("/ws", func(w http.ResponseWriter, r *http.Request) {
		err := s.melody.HandleRequest(w, r)
		if err != nil {
			s.log.ErrorContext(r.Context(), "Upgrading request to WS", "err", err)

			w.WriteHeader(http.StatusInternalServerError)
			_, _ = fmt.Fprint(w, err)
		}
	})

	s.melody.HandleMessage(func(_ *melody.Session, msg []byte) {
		s.melody.Broadcast(msg)
	})

	return s
}

// WithCatalog enables routes related to the ingredients, doughs, and tools. A database.InMemoryDatabase is required to
// enable this endpoint group.
// This database is safe to be used concurrently and thus may be shared with other endpoint groups.
func (s *Server) WithCatalog(db *database.Catalog) *Server {
	s.router.Group(func(r chi.Router) {
		s.traceInstaller.Install(r, "catalog")

		r.Use(ValidateUserMiddleware)
		r.Use(errorinjector.InjectErrorHeadersMiddleware)

		r.Get("/api/ingredients/{type}", func(w http.ResponseWriter, r *http.Request) {
			ingredientType := chi.URLParam(r, "type")
			ingredients, err := db.GetIngredients(r.Context(), ingredientType)
			if err != nil {
				s.log.ErrorContext(r.Context(), "Failed to get ingredients from database", "err", err)
				w.WriteHeader(http.StatusInternalServerError)
				return
			}

			if len(ingredients) == 0 {
				w.WriteHeader(http.StatusBadRequest)
				slog.Warn("Did not find any ingredients", "type", ingredientType)
				_, _ = fmt.Fprintf(w, "Unknown ingredient %q", ingredientType)
				return
			}

			s.log.InfoContext(r.Context(), "Ingredients requested", "type", ingredientType)

			err = json.NewEncoder(w).Encode(map[string][]model.Ingredient{"ingredients": ingredients})
			if err != nil {
				s.log.ErrorContext(r.Context(), "Failed to encode response", "err", err)
				w.WriteHeader(http.StatusInternalServerError)
				return
			}
		})

		r.Get("/api/doughs", func(w http.ResponseWriter, r *http.Request) {
			s.log.InfoContext(r.Context(), "Doughs requested")

			doughs, err := db.GetDoughs(r.Context())
			if err != nil {
				s.log.ErrorContext(r.Context(), "Failed to get doughs from database", "err", err)
				w.WriteHeader(http.StatusInternalServerError)
				return
			}

			err = json.NewEncoder(w).Encode(map[string][]model.Dough{"doughs": doughs})
			if err != nil {
				s.log.ErrorContext(r.Context(), "Failed to encode response", "err", err)
				w.WriteHeader(http.StatusInternalServerError)
				return
			}
		})

		r.Get("/api/tools", func(w http.ResponseWriter, r *http.Request) {
			s.log.InfoContext(r.Context(), "Tools requested")

			tools, err := db.GetTools(r.Context())
			if err != nil {
				s.log.ErrorContext(r.Context(), "Failed to get tools from database", "err", err)
				w.WriteHeader(http.StatusInternalServerError)
				return
			}

			err = json.NewEncoder(w).Encode(map[string][]string{"tools": tools})
			if err != nil {
				slog.ErrorContext(r.Context(), "Failed to encode response", "err", err)
				w.WriteHeader(http.StatusInternalServerError)
				return
			}
		})

		r.Get("/api/internal/recommendations", func(w http.ResponseWriter, r *http.Request) {
			s.log.InfoContext(r.Context(), "Recommendations requested")
			token := r.Header.Get("Authorization")
			if token == "" {
				if tokenCookie, err := r.Cookie("admin_token"); err == nil {
					token = tokenCookie.Value
				}
			}

			if token == "" {
				w.WriteHeader(http.StatusUnauthorized)
				return
			}

			//token = strings.TrimPrefix(token, "Bearer ")
			//if _, ok := s.db.userSessionTokens[token]; !ok {
			//	w.WriteHeader(http.StatusUnauthorized)
			//	return
			//}

			history, err := db.GetHistory(r.Context(), 10)
			if err != nil {
				s.log.ErrorContext(r.Context(), "Failed to fetch history from db", "err", err)
				w.WriteHeader(http.StatusInternalServerError)
				return
			}

			err = json.NewEncoder(w).Encode(map[string][]model.Pizza{"pizzas": history})
			if err != nil {
				s.log.ErrorContext(r.Context(), "Failed to encode response", "err", err)
				w.WriteHeader(http.StatusInternalServerError)
				return
			}
		})

		r.Post("/api/internal/recommendations", func(w http.ResponseWriter, r *http.Request) {
			if r.Header.Get("X-Is-Internal") == "" {
				w.WriteHeader(http.StatusUnauthorized)
				return
			}

			var latestRecommendation model.Pizza

			dec := json.NewDecoder(r.Body)
			dec.DisallowUnknownFields()
			err := dec.Decode(&latestRecommendation)
			if err != nil {
				s.log.ErrorContext(r.Context(), "Failed to decode request", err)
				w.WriteHeader(http.StatusBadRequest)
				return
			}

			if err := db.RecordRecommendation(r.Context(), latestRecommendation); err != nil {
				s.log.ErrorContext(r.Context(), "Failed to save recommendation", "err", err)
				w.WriteHeader(http.StatusInternalServerError)
				return
			}
			w.WriteHeader(http.StatusCreated)
		})

		r.Get("/api/login", func(w http.ResponseWriter, r *http.Request) {
			s.log.InfoContext(r.Context(), "Login requested")
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
			// TODO: Develop an authentication microservice. Perhaps overengineer it with JWT.
			// if s.db.userSessionTokens == nil {
			// 	s.db.userSessionTokens = make(map[string]time.Time)
			// }
			// s.db.userSessionTokens[token] = time.Now()

			http.SetCookie(w, &http.Cookie{
				Name:     "admin_token",
				Value:    token,
				SameSite: http.SameSiteStrictMode,
				Path:     "/", // Required for /admin to be able to use a cookie returned by /api.
			})
			err := json.NewEncoder(w).Encode(map[string]string{"token": token})
			if err != nil {
				s.log.ErrorContext(r.Context(), "Failed to encode response", "err", err)
				w.WriteHeader(http.StatusInternalServerError)
				return
			}
		})
	})

	return s
}

// WithCopy enables copy (i.e. prose) related endpoints.
func (s *Server) WithCopy(db *database.Copy) *Server {
	s.router.Group(func(r chi.Router) {
		s.traceInstaller.Install(r, "copy")

		r.Use(ValidateUserMiddleware)
		r.Use(errorinjector.InjectErrorHeadersMiddleware)

		r.Get("/api/quotes", func(w http.ResponseWriter, r *http.Request) {
			s.log.InfoContext(r.Context(), "Quotes requested")

			quotes, err := db.GetQuotes(r.Context())
			if err != nil {
				s.log.ErrorContext(r.Context(), "Failed to fetch quotes from db", "err", err)
				w.WriteHeader(http.StatusInternalServerError)
			}
			err = json.NewEncoder(w).Encode(map[string][]string{"quotes": quotes})
			if err != nil {
				s.log.ErrorContext(r.Context(), "Failed to encode response", "err", err)
				w.WriteHeader(http.StatusInternalServerError)
				return
			}
		})

		r.Get("/api/names", func(w http.ResponseWriter, r *http.Request) {
			s.log.InfoContext(r.Context(), "Names requested")

			names, err := db.GetClassicalNames(r.Context())
			if err != nil {
				s.log.ErrorContext(r.Context(), "Failed to fetch names from db", "err", err)
				w.WriteHeader(http.StatusInternalServerError)
			}

			err = json.NewEncoder(w).Encode(map[string][]string{"names": names})
			if err != nil {
				s.log.ErrorContext(r.Context(), "Failed to encode response", "err", err)
				w.WriteHeader(http.StatusInternalServerError)
				return
			}
		})

		r.Get("/api/adjectives", func(w http.ResponseWriter, r *http.Request) {
			s.log.InfoContext(r.Context(), "Adjectives requested")

			adjs, err := db.GetAdjectives(r.Context())
			if err != nil {
				s.log.ErrorContext(r.Context(), "Failed to fetch adjectives from db", "err", err)
				w.WriteHeader(http.StatusInternalServerError)
			}

			err = json.NewEncoder(w).Encode(map[string][]string{"adjectives": adjs})
			if err != nil {
				s.log.ErrorContext(r.Context(), "Failed to encode response", "err", err)
				w.WriteHeader(http.StatusInternalServerError)
				return
			}
		})
	})

	return s
}

// WithRecommendations enables the recommendations endpoint in this Server. This endpoint is stateless and thus needs
// the URLs for the Catalog and Copy services.
func (s *Server) WithRecommendations(catalogClient CatalogClient, copyClient CopyClient) *Server {
	s.router.Group(func(r chi.Router) {
		s.traceInstaller.Install(r, "recommendations")

		r.Use(ValidateUserMiddleware)
		r.Use(errorinjector.InjectErrorHeadersMiddleware)

		r.Post("/api/pizza", func(w http.ResponseWriter, r *http.Request) {
			// Add request context to catalog and copy clients. This context contains a reference to the tracer used
			// by the server (if any), which allows clients to both generate traces for outgoing client-type traces
			// without explicitly configuring a tracer, and to link said client traces with the server trace that is
			// generated in this request.
			catalogClient := catalogClient.WithRequestContext(r.Context())
			copyClient := copyClient.WithRequestContext(r.Context())

			tracer := trace.SpanFromContext(r.Context()).TracerProvider().Tracer("")

			s.log.InfoContext(r.Context(), "Received pizza recommendation request")
			var restrictions Restrictions

			dec := json.NewDecoder(r.Body)
			dec.DisallowUnknownFields()
			err := dec.Decode(&restrictions)
			if err != nil {
				s.log.ErrorContext(r.Context(), "Failed to decode request body", "err", err)
				w.WriteHeader(http.StatusBadRequest)
				return
			}

			restrictions = restrictions.WithDefaults()

			oils, err := catalogClient.Ingredients("olive_oil")
			if err != nil {
				s.log.ErrorContext(r.Context(), "Requesting ingredients", "err", err)
				w.WriteHeader(http.StatusInternalServerError)
				return
			}

			// Retrieve list of ingredients from Catalog.
			var validOliveOils []model.Ingredient
			for _, oliveOil := range oils {
				if !contains(restrictions.ExcludedIngredients, oliveOil.Name) && (!restrictions.MustBeVegetarian || oliveOil.Vegetarian) {
					validOliveOils = append(validOliveOils, oliveOil)
				}
			}

			tomatoes, err := catalogClient.Ingredients("tomato")
			if err != nil {
				s.log.ErrorContext(r.Context(), "Requesting ingredients", "err", err)
				w.WriteHeader(http.StatusInternalServerError)
				return
			}

			var validTomatoes []model.Ingredient
			for _, tomato := range tomatoes {
				if !contains(restrictions.ExcludedIngredients, tomato.Name) && (!restrictions.MustBeVegetarian || tomato.Vegetarian) {
					validTomatoes = append(validTomatoes, tomato)
				}
			}

			mozzarellas, err := catalogClient.Ingredients("mozzarella")
			if err != nil {
				s.log.ErrorContext(r.Context(), "Requesting ingredients", "err", err)
				w.WriteHeader(http.StatusInternalServerError)
				return
			}

			var validMozzarellas []model.Ingredient
			for _, mozzarella := range mozzarellas {
				if !contains(restrictions.ExcludedIngredients, mozzarella.Name) && (!restrictions.MustBeVegetarian || mozzarella.Vegetarian) {
					validMozzarellas = append(validMozzarellas, mozzarella)
				}
			}

			toppings, err := catalogClient.Ingredients("topping")
			if err != nil {
				s.log.ErrorContext(r.Context(), "Requesting ingredients", "err", err)
				w.WriteHeader(http.StatusInternalServerError)
				return
			}

			var validToppings []model.Ingredient
			for _, topping := range toppings {
				if !contains(restrictions.ExcludedIngredients, topping.Name) && (!restrictions.MustBeVegetarian || topping.Vegetarian) {
					validToppings = append(validToppings, topping)
				}
			}

			tools, err := catalogClient.Tools()
			if err != nil {
				s.log.ErrorContext(r.Context(), "Requesting tools", "err", err)
				w.WriteHeader(http.StatusInternalServerError)
				return
			}

			var validTools []string
			for _, tool := range tools {
				if !contains(restrictions.ExcludedTools, tool) {
					validTools = append(validTools, tool)
				}
			}

			doughs, err := catalogClient.Doughs()
			if err != nil {
				s.log.ErrorContext(r.Context(), "Requesting doughs", "err", err)
				w.WriteHeader(http.StatusInternalServerError)
				return
			}

			// Retrieve adjectives and names from Copy.
			adjectives, err := copyClient.Adjectives()
			if err != nil {
				s.log.ErrorContext(r.Context(), "Requesting adjectives", "err", err)
				w.WriteHeader(http.StatusInternalServerError)
				return
			}

			names, err := copyClient.Names()
			if err != nil {
				s.log.ErrorContext(r.Context(), "Requesting names", "err", err)
				w.WriteHeader(http.StatusInternalServerError)
				return
			}

			pizzaCtx, pizzaSpan := tracer.Start(r.Context(), "pizza-generation")
			var p model.Pizza
			for i := 0; i < 10; i++ {
				_, nameSpan := tracer.Start(pizzaCtx, "name-generation")
				var randomName string
				for {
					randomName = fmt.Sprintf("%s %s", adjectives[rand.Intn(len(adjectives))], names[rand.Intn(len(names))])
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
				nameSpan.End()

				p = model.Pizza{
					Name:        randomName,
					Dough:       doughs[rand.Intn(len(doughs))],
					Ingredients: []model.Ingredient{validOliveOils[rand.Intn(len(validOliveOils))], validTomatoes[rand.Intn(len(validTomatoes))], validMozzarellas[rand.Intn(len(validMozzarellas))]},
					Tool:        validTools[rand.Intn(len(validTools))],
				}

				// Compute how many extra toppings we are allowed to add. If any, randomize that number.
				extraToppings := restrictions.MaxNumberOfToppings - restrictions.MinNumberOfToppings
				if extraToppings > 0 {
					extraToppings = rand.Intn(extraToppings + 1)
				}

				for j := 0; j < extraToppings+restrictions.MinNumberOfToppings; j++ {
					p.Ingredients = append(p.Ingredients, validToppings[rand.Intn(len(validToppings))])
				}

				uniqueIngredients := make(map[string]model.Ingredient)
				for _, ingredient := range p.Ingredients {
					uniqueIngredients[ingredient.Name] = ingredient
				}
				p.Ingredients = make([]model.Ingredient, 0)
				for _, ingredient := range uniqueIngredients {
					p.Ingredients = append(p.Ingredients, ingredient)
				}

				if p.CalculateCalories() > restrictions.MaxCaloriesPerSlice {
					continue
				}

				break
			}
			pizzaSpan.End()

			pizzaRecommendation := PizzaRecommendation{
				Pizza:      p,
				Calories:   p.CalculateCalories(),
				Vegetarian: p.IsVegetarian(),
			}

			err = catalogClient.RecordRecommendation(p)
			if err != nil {
				s.log.ErrorContext(r.Context(), "Storing recommendation in catalog", "err", err)
				w.WriteHeader(http.StatusInternalServerError)
				return
			}

			pizzaRecommendations.With(prometheus.Labels{
				"vegetarian": strconv.FormatBool(pizzaRecommendation.Vegetarian),
				"tool":       pizzaRecommendation.Pizza.Tool,
			}).Inc()

			numberOfIngredientsPerPizza.Observe(float64(len(p.Ingredients)))
			pizzaCaloriesPerSlice.Observe(float64(pizzaRecommendation.Calories))

			s.log.InfoContext(r.Context(), "New pizza recommendation", "pizza", pizzaRecommendation.Pizza.Name)

			err = json.NewEncoder(w).Encode(pizzaRecommendation)
			if err != nil {
				s.log.ErrorContext(r.Context(), "Failed to encode pizza recommendation", "err", err)
				w.WriteHeader(http.StatusInternalServerError)
				return
			}
		})
	})

	return s
}

func contains(slice []string, value string) bool {
	for _, item := range slice {
		if item == value {
			return true
		}
	}
	return false
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
		next.ServeHTTP(ww, r)
		duration := time.Since(start)
		httpRequests.WithLabelValues(r.Method, r.URL.Path, strconv.Itoa(ww.Status())).Inc()
		httpRequestDuration.WithLabelValues(r.Method, r.URL.Path, strconv.Itoa(ww.Status())).Observe(duration.Seconds())
	})
}
