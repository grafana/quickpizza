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
	"github.com/grafana/quickpizza/pkg/database"
	"github.com/grafana/quickpizza/pkg/pizza"
	"github.com/grafana/quickpizza/pkg/web"
	"github.com/olahol/melody"
	"github.com/prometheus/client_golang/prometheus"
	"github.com/prometheus/client_golang/prometheus/promauto"
	"github.com/prometheus/client_golang/prometheus/promhttp"
	"github.com/rs/xid"
	"go.opentelemetry.io/contrib/instrumentation/net/http/otelhttp"
	"go.opentelemetry.io/otel/propagation"
	"go.opentelemetry.io/otel/trace"
	"go.uber.org/zap"
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
	Pizza      pizza.Pizza `json:"pizza"`
	Calories   int         `json:"calories"`
	Vegetarian bool        `json:"vegetarian"`
}

// Server is the object that handles HTTP requests and computes pizza recommendations.
// Routes are divided into serveral groups that can be instantiated independently as microservices, or all together
// as one single big service.
type Server struct {
	log    *zap.Logger
	trace  trace.TracerProvider
	router chi.Router
	melody *melody.Melody
}

func NewServer(logger *zap.Logger) (*Server, error) {
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
		log:    logger,
		trace:  trace.NewNoopTracerProvider(),
		router: router,
		melody: melody.New(),
	}, nil
}

func (s *Server) ServeHTTP(rw http.ResponseWriter, r *http.Request) {
	s.router.ServeHTTP(rw, r)
}

// WithTracing registers the specified TracerProvider within the Server.
// Subsequent handlers can use s.trace to create more detailed traces than what it would be possible if we
// applied the same tracing middleware to the whole server.
func (s *Server) WithTracing(provider trace.TracerProvider) *Server {
	s.trace = provider

	return s
}

// WithPrometheus adds a /metrics endpoint and instrument subsequently enabled groups with general http-level metrics.
func (s *Server) WithPrometheus() *Server {
	// Add MW with .With instead of .Use, as .Use does not allow registering MWs after routes.
	s.router = s.router.With(PrometheusMiddleware)
	s.router.Handle("/metrics", promhttp.Handler())

	return s
}

// WithFrontend enables serving the embedded Svelte frontend.
func (s *Server) WithFrontend() *Server {
	s.router.Group(func(r chi.Router) {
		r.Use(func(handler http.Handler) http.Handler {
			return otelhttp.NewHandler(
				handler,
				"http_serve_static",
				otelhttp.WithTracerProvider(s.trace),
				// We keep the default name formatter, which defaults to `operation`, to avoid increasing cardinality
				// with static URIs.
				// No need for trace propagators in the frontend.
				// Frontend requests are always public.
				otelhttp.WithPublicEndpoint(),
			)
		})

		r.Handle("/*", SvelteKitHandler("/*"))
	})

	return s
}

// WithGateway enables a gateway that routes external requests to the respective services.
// This endpoint should be typically enabled toget with WithFrontend on a microservices-based deployment.
// TODO: So far the gateway only handles a few endpoints.
func (s *Server) WithGateway(catalogUrl, copyUrl, wsUrl, recommendationsUrl string) *Server {
	s.router.Group(func(r chi.Router) {
		r.Use(func(handler http.Handler) http.Handler {
			return otelhttp.NewHandler(
				handler,
				"http_gateway",
				otelhttp.WithTracerProvider(s.trace),
				// https://opentelemetry.io/docs/specs/otel/trace/semantic_conventions/http/#name
				otelhttp.WithSpanNameFormatter(func(_ string, r *http.Request) string {
					return fmt.Sprintf("%s %s", r.Method, r.URL.Path)
				}),
				// Gateway requests are always public.
				otelhttp.WithPublicEndpoint(),
			)
		})

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
				}

				request.SetURL(u)
				s.log.Info("Proxying request", zap.String("url", request.Out.URL.String()))

				// Mark outgoing requests as internal so trace context is trusted.
				request.Out.Header.Add("X-Internal-Token", "secret")
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
			s.log.Error("Upgrading request to WS", zap.Error(err))

			w.WriteHeader(http.StatusInternalServerError)
			_, _ = fmt.Fprint(w, err)
		}
	})

	s.melody.HandleMessage(func(_ *melody.Session, msg []byte) {
		s.melody.Broadcast(msg)
	})

	return s
}

// WithCatalog enables routes related to the ingredients, doughs, and tools. An database.InMemoryDatabase is required to
// enable this endpoint group.
// This database is safe to be used concurrently and thus may be shared with other endpoint groups.
func (s *Server) WithCatalog(db *database.InMemoryDatabase) *Server {
	s.router.Group(func(r chi.Router) {
		// Set tracing middleware. This will generate traces for incoming requests.
		r.Use(func(handler http.Handler) http.Handler {
			return otelhttp.NewHandler(
				handler,
				"http_catalog",
				otelhttp.WithTracerProvider(s.trace),
				// Get trace context from requests.
				otelhttp.WithPropagators(propagation.TraceContext{}),
				// Identify requests as public based on the presence of the secret `X-Internal-Token`.
				// If the request is considered public, any Parent trace ID present in the request header is considered
				// untrusted and a weaker relation is established.
				otelhttp.WithPublicEndpointFn(func(r *http.Request) bool {
					return r.Header.Get("X-Internal-Token") != "secret"
				}),
				// https://opentelemetry.io/docs/specs/otel/trace/semantic_conventions/http/#name
				otelhttp.WithSpanNameFormatter(func(_ string, r *http.Request) string {
					return fmt.Sprintf("%s %s", r.Method, r.URL.Path)
				}),
			)
		})

		r.Use(ValidateUserMiddleware)

		r.Get("/api/ingredients/{type}", func(w http.ResponseWriter, r *http.Request) {
			logger := loggerWithUserID(s.log, r)
			ingredientType := chi.URLParam(r, "type")
			isVegetarian := r.URL.Query().Get("is_vegetarian")

			var ingredients []pizza.Ingredient
			db.Transaction(func(data *database.Data) {
				switch ingredientType {
				case "olive_oil":
					ingredients = append(ingredients, data.OliveOils...)
				case "tomato":
					ingredients = append(ingredients, data.Tomatoes...)
				case "mozzarella":
					ingredients = append(ingredients, data.Mozzarellas...)
				case "topping":
					ingredients = append(ingredients, data.Toppings...)
				}
			})

			if len(ingredients) == 0 {
				w.WriteHeader(http.StatusBadRequest)
				_, _ = fmt.Fprintf(w, "Unknown ingredient %q", ingredientType)
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

			err := json.NewEncoder(w).Encode(map[string][]pizza.Ingredient{"ingredients": filteredIngredients})
			if err != nil {
				logger.Error("Failed to encode response", zap.Error(err))
				w.WriteHeader(http.StatusInternalServerError)
				return
			}
		})

		r.Get("/api/doughs", func(w http.ResponseWriter, r *http.Request) {
			logger := loggerWithUserID(s.log, r)
			logger.Info("Doughs requested")

			var doughs []pizza.Dough
			db.Transaction(func(data *database.Data) {
				doughs = append(doughs, data.Doughs...)
			})

			err := json.NewEncoder(w).Encode(map[string][]pizza.Dough{"doughs": doughs})
			if err != nil {
				logger.Error("Failed to encode response", zap.Error(err))
				w.WriteHeader(http.StatusInternalServerError)
				return
			}
		})

		r.Get("/api/tools", func(w http.ResponseWriter, r *http.Request) {
			logger := loggerWithUserID(s.log, r)
			logger.Info("Tools requested")

			var tools []string
			db.Transaction(func(data *database.Data) {
				tools = append(tools, data.Tools...)
			})

			err := json.NewEncoder(w).Encode(map[string][]string{"tools": tools})
			if err != nil {
				logger.Error("Failed to encode response", zap.Error(err))
				w.WriteHeader(http.StatusInternalServerError)
				return
			}
		})

		r.Get("/api/internal/recommendations", func(w http.ResponseWriter, r *http.Request) {
			logger := loggerWithUserID(s.log, r)
			logger.Info("Recommendations requested")
			token := r.Header.Get("Authorization")
			if token == "" {
				w.WriteHeader(http.StatusUnauthorized)
				return
			}

			//token = strings.TrimPrefix(token, "Bearer ")
			//if _, ok := s.db.userSessionTokens[token]; !ok {
			//	w.WriteHeader(http.StatusUnauthorized)
			//	return
			//}

			err := json.NewEncoder(w).Encode(map[string][]pizza.Pizza{"pizzas": db.History()})
			if err != nil {
				logger.Error("Failed to encode response", zap.Error(err))
				w.WriteHeader(http.StatusInternalServerError)
				return
			}
		})

		r.Post("/api/internal/recommendations", func(w http.ResponseWriter, r *http.Request) {
			if r.Header.Get("X-Internal-Token") != "secret" {
				w.WriteHeader(http.StatusUnauthorized)
				return
			}

			var latestRecommendation pizza.Pizza

			dec := json.NewDecoder(r.Body)
			dec.DisallowUnknownFields()
			err := dec.Decode(&latestRecommendation)
			if err != nil {
				s.log.Error("Failed to decode request", zap.Error(err))
				w.WriteHeader(http.StatusBadRequest)
				return
			}

			db.SetLatestPizza(latestRecommendation)
			w.WriteHeader(http.StatusCreated)
		})

		r.Get("/api/login", func(w http.ResponseWriter, r *http.Request) {
			logger := loggerWithUserID(s.log, r)
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
			//if s.db.userSessionTokens == nil {
			//	s.db.userSessionTokens = make(map[string]time.Time)
			//}
			//s.db.userSessionTokens[token] = time.Now()
			err := json.NewEncoder(w).Encode(map[string]string{"token": token})
			if err != nil {
				logger.Error("Failed to encode response", zap.Error(err))
				w.WriteHeader(http.StatusInternalServerError)
				return
			}
		})
	})

	return s
}

// WithCopy enables copy (i.e. prose) related endpoints.
func (s *Server) WithCopy(db *database.InMemoryDatabase) *Server {
	s.router.Group(func(r chi.Router) {
		r.Use(func(handler http.Handler) http.Handler {
			return otelhttp.NewHandler(
				handler,
				"http_copy",
				otelhttp.WithTracerProvider(s.trace),
				// Get trace context from requests.
				otelhttp.WithPropagators(propagation.TraceContext{}),
				// Identify requests as public based on the presence of the secret `X-Internal-Token`.
				otelhttp.WithPublicEndpointFn(func(r *http.Request) bool {
					return r.Header.Get("X-Internal-Token") != "secret"
				}),
				// https://opentelemetry.io/docs/specs/otel/trace/semantic_conventions/http/#name
				otelhttp.WithSpanNameFormatter(func(_ string, r *http.Request) string {
					return fmt.Sprintf("%s %s", r.Method, r.URL.Path)
				}),
			)
		})

		r.Use(ValidateUserMiddleware)

		r.Get("/api/quotes", func(w http.ResponseWriter, r *http.Request) {
			logger := loggerWithUserID(s.log, r)
			logger.Info("Quotes requested")

			var quotes []string
			db.Transaction(func(data *database.Data) {
				quotes = append(quotes, data.Quotes...)
			})

			err := json.NewEncoder(w).Encode(map[string][]string{"quotes": quotes})
			if err != nil {
				logger.Error("Failed to encode response", zap.Error(err))
				w.WriteHeader(http.StatusInternalServerError)
				return
			}
		})

		r.Get("/api/names", func(w http.ResponseWriter, r *http.Request) {
			logger := loggerWithUserID(s.log, r)
			logger.Info("Names requested")

			var names []string
			db.Transaction(func(data *database.Data) {
				names = append(names, data.ClassicNames...)
			})

			err := json.NewEncoder(w).Encode(map[string][]string{"names": names})
			if err != nil {
				logger.Error("Failed to encode response", zap.Error(err))
				w.WriteHeader(http.StatusInternalServerError)
				return
			}
		})

		r.Get("/api/adjectives", func(w http.ResponseWriter, r *http.Request) {
			logger := loggerWithUserID(s.log, r)
			logger.Info("Adjectives requested")

			var adjs []string
			db.Transaction(func(data *database.Data) {
				adjs = append(adjs, data.Adjectives...)
			})

			err := json.NewEncoder(w).Encode(map[string][]string{"adjectives": adjs})
			if err != nil {
				logger.Error("Failed to encode response", zap.Error(err))
				w.WriteHeader(http.StatusInternalServerError)
				return
			}
		})
	})

	return s
}

// WithRecommendations enables the recommendations endpoint in this Server. This endpoint is stateless and thus needs
// the URLs for the Catalog and Copy services.
func (s *Server) WithRecommendations(catalogUrl, copyUrl string) *Server {
	catalogClient := CatalogClient{CatalogUrl: catalogUrl}
	copyClient := CopyClient{CopyURL: copyUrl}

	s.router.Group(func(r chi.Router) {
		r.Use(func(handler http.Handler) http.Handler {
			return otelhttp.NewHandler(
				handler,
				"recommendation_api",
				otelhttp.WithTracerProvider(s.trace),
				// Get trace context from requests.
				otelhttp.WithPropagators(propagation.TraceContext{}),
				// Identify requests as public based on the presence of the secret `X-Internal-Token`.
				otelhttp.WithPublicEndpointFn(func(r *http.Request) bool {
					return r.Header.Get("X-Internal-Token") != "secret"
				}),
				// https://opentelemetry.io/docs/specs/otel/trace/semantic_conventions/http/#name
				otelhttp.WithSpanNameFormatter(func(_ string, r *http.Request) string {
					return fmt.Sprintf("%s %s", r.Method, r.URL.Path)
				}),
			)
		})

		r.Use(ValidateUserMiddleware)

		r.Post("/api/pizza", func(w http.ResponseWriter, r *http.Request) {
			// Add request context to catalog and copy clients. This context contains a reference to the tracer used
			// by the server (if any), which allows clients to both generate traces for outgoing client-type traces
			// without explicitly configuring a tracer, and to link said client traces with the server trace that is
			// generated in this request.
			catalogClient = catalogClient.WithRequestContext(r.Context())
			copyClient = copyClient.WithRequestContext(r.Context())

			logger := loggerWithUserID(s.log, r)
			logger.Info("Received pizza recommendation request")
			var restrictions pizza.Restrictions

			dec := json.NewDecoder(r.Body)
			dec.DisallowUnknownFields()
			err := dec.Decode(&restrictions)
			if err != nil {
				logger.Error("Failed to decode request body", zap.Error(err))
				w.WriteHeader(http.StatusBadRequest)
				return
			}

			restrictions = restrictions.WithDefaults()

			oils, err := catalogClient.Ingredients("olive_oil")
			if err != nil {
				logger.Error("Requesting ingredients", zap.Error(err))
				w.WriteHeader(http.StatusInternalServerError)
				return
			}

			// Retrieve list of ingredients from Catalog.
			var validOliveOils []pizza.Ingredient
			for _, oliveOil := range oils {
				if !contains(restrictions.ExcludedIngredients, oliveOil.Name) && (!restrictions.MustBeVegetarian || oliveOil.Vegetarian) {
					validOliveOils = append(validOliveOils, oliveOil)
				}
			}

			tomatoes, err := catalogClient.Ingredients("tomato")
			if err != nil {
				logger.Error("Requesting ingredients", zap.Error(err))
				w.WriteHeader(http.StatusInternalServerError)
				return
			}

			var validTomatoes []pizza.Ingredient
			for _, tomato := range tomatoes {
				if !contains(restrictions.ExcludedIngredients, tomato.Name) && (!restrictions.MustBeVegetarian || tomato.Vegetarian) {
					validTomatoes = append(validTomatoes, tomato)
				}
			}

			mozzarellas, err := catalogClient.Ingredients("mozzarella")
			if err != nil {
				logger.Error("Requesting ingredients", zap.Error(err))
				w.WriteHeader(http.StatusInternalServerError)
				return
			}

			var validMozzarellas []pizza.Ingredient
			for _, mozzarella := range mozzarellas {
				if !contains(restrictions.ExcludedIngredients, mozzarella.Name) && (!restrictions.MustBeVegetarian || mozzarella.Vegetarian) {
					validMozzarellas = append(validMozzarellas, mozzarella)
				}
			}

			toppings, err := catalogClient.Ingredients("topping")
			if err != nil {
				logger.Error("Requesting ingredients", zap.Error(err))
				w.WriteHeader(http.StatusInternalServerError)
				return
			}

			var validToppings []pizza.Ingredient
			for _, topping := range toppings {
				if !contains(restrictions.ExcludedIngredients, topping.Name) && (!restrictions.MustBeVegetarian || topping.Vegetarian) {
					validToppings = append(validToppings, topping)
				}
			}

			tools, err := catalogClient.Tools()
			if err != nil {
				logger.Error("Requesting tools", zap.Error(err))
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
				logger.Error("Requesting doughs", zap.Error(err))
				w.WriteHeader(http.StatusInternalServerError)
				return
			}

			// Retrieve adjectives and names from Copy.
			adjectives, err := copyClient.Adjectives()
			if err != nil {
				logger.Error("Requesting adjectives", zap.Error(err))
				w.WriteHeader(http.StatusInternalServerError)
				return
			}

			names, err := copyClient.Names()
			if err != nil {
				logger.Error("Requesting names", zap.Error(err))
				w.WriteHeader(http.StatusInternalServerError)
				return
			}

			_, pizzaSpan := trace.SpanFromContext(r.Context()).TracerProvider().Tracer("").Start(
				r.Context(),
				"pizza-generation",
			)
			var p pizza.Pizza
			for i := 0; i < 10; i++ {
				_, nameSpan := pizzaSpan.TracerProvider().Tracer("").Start(
					r.Context(),
					"name-generation",
				)
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

				p = pizza.Pizza{
					Name:        randomName,
					Dough:       doughs[rand.Intn(len(doughs))],
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
			pizzaSpan.End()

			pizzaRecommendation := PizzaRecommendation{
				Pizza:      p,
				Calories:   p.CalculateCalories(),
				Vegetarian: p.IsVegetarian(),
			}

			err = catalogClient.RecordRecommendation(p)
			if err != nil {
				logger.Error("Storing recommendation in catalog", zap.Error(err))
				// Continue anyway.
			}

			pizzaRecommendations.With(prometheus.Labels{
				"vegetarian": strconv.FormatBool(pizzaRecommendation.Vegetarian),
				"tool":       pizzaRecommendation.Pizza.Tool,
			}).Inc()

			numberOfIngredientsPerPizza.Observe(float64(len(p.Ingredients)))
			pizzaCaloriesPerSlice.Observe(float64(pizzaRecommendation.Calories))

			logger.Info("New pizza recommendation", zap.String("user", r.Context().Value("user").(string)), zap.Any("pizza", pizzaRecommendation.Pizza.Name))

			err = json.NewEncoder(w).Encode(pizzaRecommendation)
			if err != nil {
				logger.Error("Failed to encode pizza recommendation", zap.Error(err))
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
