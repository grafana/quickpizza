package http

import (
	"bytes"
	"context"
	crand "crypto/rand"
	"encoding/json"
	"encoding/xml"
	"errors"
	"fmt"
	"html/template"
	"io"
	"io/fs"
	"log"
	"math/rand"
	"net/http"
	"net/http/httputil"
	_ "net/http/pprof"
	"net/url"
	"os"
	"slices"
	"strconv"
	"strings"
	"time"

	"log/slog"

	"github.com/go-chi/chi/v5"
	"github.com/go-chi/chi/v5/middleware"
	"github.com/go-chi/cors"
	"github.com/go-chi/httplog/v2"
	"github.com/olahol/melody"
	"github.com/prometheus/client_golang/prometheus"
	"github.com/prometheus/client_golang/prometheus/promauto"
	"github.com/prometheus/client_golang/prometheus/promhttp"
	"github.com/rs/xid"
	"go.opentelemetry.io/contrib/instrumentation/net/http/otelhttp"
	"go.opentelemetry.io/otel/propagation"
	"go.opentelemetry.io/otel/trace"

	k6 "github.com/grafana/pyroscope-go/x/k6"
	"github.com/grafana/quickpizza/pkg/database"
	"github.com/grafana/quickpizza/pkg/errorinjector"
	"github.com/grafana/quickpizza/pkg/logging"
	"github.com/grafana/quickpizza/pkg/model"
	"github.com/grafana/quickpizza/pkg/util"
	"github.com/grafana/quickpizza/pkg/web"
)

// Variables storing prometheus metrics.
var (
	pizzaRecommendations = promauto.NewCounterVec(prometheus.CounterOpts{
		Namespace: "k6quickpizza",
		Subsystem: "server",
		Name:      "pizza_recommendations_total",
		Help:      "The total number of pizza recommendations",
	}, []string{"vegetarian", "tool"})

	numberOfIngredientsPerPizza = promauto.NewHistogram(prometheus.HistogramOpts{
		Namespace: "k6quickpizza",
		Subsystem: "server",
		Name:      "number_of_ingredients_per_pizza",
		Help:      "The number of ingredients per pizza",
		Buckets:   []float64{1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20},
	})

	numberOfIngredientsPerPizzaNativeHistogram = promauto.NewHistogram(prometheus.HistogramOpts{
		Namespace:                       "k6quickpizza",
		Subsystem:                       "server",
		Name:                            "number_of_ingredients_per_pizza_alternate",
		Help:                            "The number of ingredients per pizza (Native Histogram)",
		NativeHistogramBucketFactor:     1.1,
		NativeHistogramMaxBucketNumber:  100,
		NativeHistogramMinResetDuration: 1 * time.Hour,
	})

	pizzaCaloriesPerSlice = promauto.NewHistogram(prometheus.HistogramOpts{
		Namespace: "k6quickpizza",
		Subsystem: "server",
		Name:      "pizza_calories_per_slice",
		Help:      "The number of calories per slice of pizza",
		Buckets:   []float64{100, 200, 300, 400, 500, 600, 700, 800, 900, 1000, 1100, 1200, 1300, 1400, 1500, 1600, 1700, 1800, 1900, 2000},
	})

	pizzaCaloriesPerSliceNativeHistogram = promauto.NewHistogram(prometheus.HistogramOpts{
		Namespace:                       "k6quickpizza",
		Subsystem:                       "server",
		Name:                            "pizza_calories_per_slice_alternate",
		Help:                            "The number of calories per slice of pizza (Native Histogram)",
		NativeHistogramBucketFactor:     1.1,
		NativeHistogramMaxBucketNumber:  100,
		NativeHistogramMinResetDuration: 1 * time.Hour,
	})

	httpRequests = promauto.NewCounterVec(prometheus.CounterOpts{
		Namespace: "k6quickpizza",
		Subsystem: "server",
		Name:      "http_requests_total",
		Help:      "The total number of HTTP requests",
	}, []string{"method", "path", "status"})

	httpRequestDuration = promauto.NewHistogramVec(prometheus.HistogramOpts{
		Namespace: "k6quickpizza",
		Subsystem: "server",
		Name:      "http_request_duration_seconds",
		Help:      "The duration of HTTP requests",
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
	CustomName          string   `json:"customName"`
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

type authKeyType int
type userKeyType int

const (
	authKey           authKeyType = 0
	userKey           userKeyType = 0
	authHeader                    = "Authorization"
	qpUserTokenCookie             = "qp_user_token"
	csrfTokenCookie               = "csrf_token"
	piDecimals                    = "1415926535897932384626433832795028841971693993751058209749445923078164"
	csrfTokenLength               = 32
)

var authError = errors.New("authentication failed")
var templateError = errors.New("error rendering template")

func requestTokenFromCookie(r *http.Request) string {
	cookie_token, err := r.Cookie(qpUserTokenCookie)
	if err == nil && cookie_token != nil {
		return cookie_token.Value
	}
	return ""
}

func getRequestToken(r *http.Request) string {
	// Try extracting token from Cookies first.
	cookie_token := requestTokenFromCookie(r)
	if len(cookie_token) == model.UserTokenLength {
		return cookie_token
	}

	// Otherwise, check the Authorization header.
	auth := r.Header.Get(authHeader)
	prefix, token, found := strings.Cut(auth, " ")
	prefix = strings.ToLower(prefix)

	if !found || (prefix != "token" && prefix != "bearer") || len(token) != model.UserTokenLength {
		return ""
	}

	return token
}

func contextUser(ctx context.Context) *model.User {
	user, ok := ctx.Value(userKey).(*model.User)
	if !ok {
		return nil
	}
	return user
}

func LogUser(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		user := contextUser(r.Context())
		if user != nil {
			httplog.LogEntrySetField(r.Context(), "user", slog.StringValue(user.Username))
		} else {
			httplog.LogEntrySetField(r.Context(), "user", slog.StringValue("NOTFOUND"))
		}
		next.ServeHTTP(w, r.WithContext(r.Context()))
	})
}

// Server is the object that handles HTTP requests and computes pizza recommendations.
// Routes are divided into serveral groups that can be instantiated independently as microservices, or all together
// as one single big service.
type Server struct {
	log            *slog.Logger
	traceInstaller *OTelInstaller
	router         chi.Router
	melody         *melody.Melody
}

func NewServer(profiling bool, traceInstaller *OTelInstaller) *Server {
	logger := slog.New(logging.NewContextLogger(slog.Default().Handler()))

	reqLogger := httplog.NewLogger("quickpizza", httplog.Options{
		JSON:             true,
		Writer:           os.Stderr,
		LogLevel:         logging.GetLogLevel(),
		Concise:          true,
		RequestHeaders:   false,
		MessageFieldName: "message",
		QuietDownRoutes: []string{
			"/",
			"/ready",
			"/healthz",
			"/metrics",
			"/contacts.php",
			"/news.php",
			"/flip_coin.php",
			"/browser.php",
			"/my_messages.php",
			"/admin.php",
			"/ws",
		},
		QuietDownPeriod: 30 * time.Second,
		ReplaceAttrsOverride: func(groups []string, a slog.Attr) slog.Attr {
			if slices.Contains([]string{"remoteIP", "proto", "message", "service", "requestID"}, a.Key) {
				// Remove from log
				return slog.Attr{}
			}
			return a
		},
	})

	router := chi.NewRouter()
	router.Use(
		PrometheusMiddleware,
		httplog.RequestLogger(reqLogger),
		middleware.Recoverer,
		cors.New(cors.Options{
			AllowedOrigins:   []string{"*"},
			AllowedMethods:   []string{"GET", "POST", "PUT", "DELETE", "OPTIONS"},
			AllowedHeaders:   []string{"Accept", authHeader, "Content-Type", "X-CSRF-Token"},
			ExposedHeaders:   []string{"Link"},
			AllowCredentials: true,
			MaxAge:           300, // Maximum value not ignored by any of major browsers
		}).Handler,
	)

	if profiling {
		router.Use(k6.LabelsFromBaggageHandler)
	} else {
		slog.Info("enabling Pyroscope profiling in Pull mode")
		router.Mount("/debug/pprof/", http.DefaultServeMux)
	}

	return &Server{
		traceInstaller: traceInstaller,
		router:         router,
		melody:         melody.New(),
		log:            logger,
	}
}

func (s *Server) ServeHTTP(rw http.ResponseWriter, r *http.Request) {
	s.router.ServeHTTP(rw, r)
}

func (s *Server) decodeJSONBody(w http.ResponseWriter, r *http.Request, v any) error {
	dec := json.NewDecoder(r.Body)
	dec.DisallowUnknownFields()
	err := dec.Decode(v)
	if err != nil {
		s.writeJSONErrorResponse(w, r, err, http.StatusBadRequest)
		return err
	}
	return nil
}

func (s *Server) writeJSONErrorResponse(w http.ResponseWriter, r *http.Request, err error, status int) {
	s.writeJSONResponse(w, r, map[string]string{"error": err.Error()}, status)
}

func (s *Server) writeJSONResponse(w http.ResponseWriter, r *http.Request, v any, status int) {
	buf := bytes.Buffer{}
	err := json.NewEncoder(&buf).Encode(v)
	if err != nil {
		s.log.ErrorContext(r.Context(), "Failed to encode JSON response", "err", err)
		w.WriteHeader(http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	_, err = w.Write(buf.Bytes())
	if err != nil {
		s.log.ErrorContext(r.Context(), "Failed to write response", "err", err)
	}
}

func (s *Server) writeXMLResponse(w http.ResponseWriter, r *http.Request, v any, status int) {
	buf := bytes.Buffer{}
	err := xml.NewEncoder(&buf).Encode(v)
	if err != nil {
		s.log.ErrorContext(r.Context(), "Failed to encode XML response", "err", err)
		w.WriteHeader(http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/xml")
	w.WriteHeader(status)
	_, err = w.Write(buf.Bytes())
	if err != nil {
		s.log.ErrorContext(r.Context(), "Failed to write response", "err", err)
	}
}

func (s *Server) AddLivenessProbes() {
	// Readiness probe
	s.router.Get("/ready", func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
	})

	// Liveness probe
	s.router.Get("/healthz", func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
	})
}

// AddPrometheusHandler adds a /metrics endpoint and instrument subsequently enabled groups with general http-level metrics.
func (s *Server) AddPrometheusHandler() {
	s.router.Handle("/metrics", promhttp.Handler())
}

// AddFrontend enables serving the embedded Svelte frontend.
func (s *Server) AddFrontend() {
	s.router.Group(func(r chi.Router) {
		s.traceInstaller.Install(r, "frontend",
			// The frontend serves a lot of static files on different paths. To save on cardinality, we override the
			// default SpanNameFormatter with one that does not include the request path in the span name.
			otelhttp.WithSpanNameFormatter(func(_ string, _ *http.Request) string {
				return "static"
			}),
		)

		r.Handle("/favicon.ico", FaviconHandler())
		r.Handle("/*", SvelteKitHandler())
	})
}

// AddConfigHandler enables serving the config server.
func (s *Server) AddConfigHandler(config map[string]string) {
	s.router.Group(func(r chi.Router) {
		s.traceInstaller.Install(r, "config")

		r.Get("/api/config", func(w http.ResponseWriter, r *http.Request) {
			s.writeJSONResponse(w, r, config, http.StatusOK)
		})
	})
}

// AddGateway enables a gateway that routes external requests to the respective services.
// This endpoint should be typically enabled toget with WithFrontend on a microservices-based deployment.
// TODO: So far the gateway only handles a few endpoints.
func (s *Server) AddGateway(catalogUrl, copyUrl, wsUrl, recommendationsUrl, configUrl string) {
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
				s.log.Debug("Reverse Proxy Request", "endpoint", request.In.URL.Path)
				switch request.In.URL.Path {
				case "/api/users/token/login":
					u, _ = url.Parse(catalogUrl)
				case "/api/quotes":
					u, _ = url.Parse(copyUrl)
				case "/api/tools":
					u, _ = url.Parse(catalogUrl)
				case "/api/ratings":
					u, _ = url.Parse(catalogUrl)
				case "/api/internal/recommendations":
					u, _ = url.Parse(catalogUrl)
				case "/api/pizza":
					u, _ = url.Parse(recommendationsUrl)
				case "/api/config":
					u, _ = url.Parse(configUrl)
				case "/api/admin/login":
					u, _ = url.Parse(catalogUrl)
				default:
					u, _ = url.Parse(catalogUrl)
				}

				request.SetURL(u)
				s.log.DebugContext(request.In.Context(), "Proxying request", "url", request.Out.URL.String())

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
}

// AddWebSocket enables serving and handle websockets.
func (s *Server) AddWebSocket() {
	s.router.Group(func(r chi.Router) {
		s.traceInstaller.Install(r, "ws")

		r.Get("/ws", func(w http.ResponseWriter, r *http.Request) {
			err := s.melody.HandleRequest(w, r)
			if err != nil {
				s.log.ErrorContext(r.Context(), "Upgrading request to WS", "err", err)

				w.WriteHeader(http.StatusInternalServerError)
				_, _ = fmt.Fprint(w, err)
			}
		})
	})

	s.melody.HandleMessage(func(_ *melody.Session, msg []byte) {
		s.melody.Broadcast(msg)
	})
}

// AddTestK6IO enables routes for replacing the legacy test.k6.io service.
// It tries to follow https://github.com/grafana/test.k6.io as closely as possible,
// even though the original service was implemented in PHP. For this reason, the paths
// defined here will sometimes end in '.php'.
func (s *Server) AddTestK6IO() {
	filesystem := http.FS(web.TestK6IO)

	staticMapping := map[string]string{
		"/contacts.php":    "test.k6.io/contacts.html",
		"/news.php":        "test.k6.io/news.html",
		"/browser.php":     "test.k6.io/browser.html",
		"/my_messages.php": "test.k6.io/my_messages.html",
		"/admin.php":       "test.k6.io/admin.html",
	}

	s.router.Group(func(r chi.Router) {
		cache := map[string][]byte{}
		for k, v := range staticMapping {
			data, _ := web.TestK6IO.ReadFile(v)
			cache[k] = data
		}

		for k := range staticMapping {
			r.HandleFunc(k, func(w http.ResponseWriter, r *http.Request) {
				w.Write(cache[k])
			})
		}

		flipTemplate := template.Must(template.ParseFS(web.TestK6IO, "test.k6.io/flip_coin.html"))

		r.Get("/flip_coin.php", func(w http.ResponseWriter, r *http.Request) {
			bet := r.URL.Query().Get("bet")
			if bet != "heads" && bet != "tails" {
				bet = "heads"
			}

			var result string
			if rand.Intn(2) == 0 {
				result = "heads"
			} else {
				result = "tails"
			}

			type PageData struct {
				Bet    string
				Result string
				Won    bool
			}

			data := PageData{
				Bet:    bet,
				Result: result,
				Won:    (bet == result),
			}

			if err := flipTemplate.Execute(w, data); err != nil {
				s.writeJSONErrorResponse(w, r, templateError, 500)
			}
		})

		r.Get("/pi.php", func(w http.ResponseWriter, r *http.Request) {
			arg := r.URL.Query().Get("decimals")
			decimals, err := strconv.Atoi(arg)
			if err != nil || decimals < 0 {
				decimals = 2
			} else if decimals > len(piDecimals) {
				decimals = len(piDecimals)
			}

			w.Write([]byte("3." + piDecimals[:decimals]))
		})

		serveFiles := func(w http.ResponseWriter, r *http.Request) {
			http.FileServer(filesystem).ServeHTTP(w, r)
		}

		r.HandleFunc("/test.k6.io/*", serveFiles)
		r.HandleFunc("/test.k6.io", serveFiles)
	})
}

// AddHTTPTesting enables routes for simple HTTP endpoint testing, like in httpbin.org.
// These are meant to replace https://github.com/grafana/httpbin (roughly).
func (s *Server) AddHTTPTesting() {
	s.router.Group(func(r chi.Router) {
		r.HandleFunc("/api/status/{status:\\d+}", func(w http.ResponseWriter, r *http.Request) {
			status, err := strconv.Atoi(chi.URLParam(r, "status"))
			if err != nil {
				w.WriteHeader(http.StatusBadRequest)
				return
			}

			if status < 100 || status > 599 {
				w.WriteHeader(http.StatusBadRequest)
				return
			}

			w.WriteHeader(status)
		})

		r.Get("/api/bytes/{n:\\d+}", func(w http.ResponseWriter, r *http.Request) {
			n, err := strconv.Atoi(chi.URLParam(r, "n"))
			if err != nil {
				n = 0
			}

			data := make([]byte, n)
			crand.Read(data)

			w.Header().Set("Content-Type", "application/octet-stream")
			w.WriteHeader(http.StatusOK)
			w.Write(data)
		})

		r.Get("/api/delay/{delay}", func(w http.ResponseWriter, r *http.Request) {
			param := chi.URLParam(r, "delay")
			delay, err := time.ParseDuration(param)
			if err != nil {
				delay, err = time.ParseDuration(param + "s")
				if err != nil {
					w.WriteHeader(http.StatusBadRequest)
					return
				}
			}

			time.Sleep(delay)
			w.WriteHeader(http.StatusOK)
		})

		r.Get("/api/get", func(w http.ResponseWriter, r *http.Request) {
			w.WriteHeader(http.StatusOK)
		})

		r.Delete("/api/delete", func(w http.ResponseWriter, r *http.Request) {
			w.WriteHeader(http.StatusOK)
		})

		fn := func(w http.ResponseWriter, r *http.Request) {
			w.Header().Set("Content-Type", r.Header.Get("Content-Type"))
			w.WriteHeader(http.StatusOK)
			io.Copy(w, r.Body)
		}

		r.Post("/api/post", fn)
		r.Put("/api/put", fn)
		r.Patch("/api/patch", fn)

		// Cookies are a type of pizza (without cheese).
		r.Get("/api/cookies", func(w http.ResponseWriter, r *http.Request) {
			cookies := map[string]string{}

			for _, cookie := range r.Cookies() {
				cookies[cookie.Name] = cookie.Value
			}

			s.writeJSONResponse(w, r, map[string]any{"cookies": cookies}, http.StatusOK)
		})

		r.Post("/api/cookies", func(w http.ResponseWriter, r *http.Request) {
			for key, value := range r.URL.Query() {
				http.SetCookie(w, &http.Cookie{Name: key, Value: value[0]})
			}
			w.WriteHeader(http.StatusOK)
		})

		r.Get("/api/headers", func(w http.ResponseWriter, r *http.Request) {
			headers := map[string]string{}

			for key, values := range r.Header {
				headers[key] = strings.Join(values, ",")
			}
			headers["Host"] = r.Host

			s.writeJSONResponse(w, r, map[string]any{"headers": headers}, http.StatusOK)
		})

		r.Get("/api/basic-auth/{username}/{password}", func(w http.ResponseWriter, r *http.Request) {
			user, pass, _ := r.BasicAuth()
			username := chi.URLParam(r, "username")
			password := chi.URLParam(r, "password")

			result := map[string]any{
				"user":          username,
				"password":      password,
				"authenticated": (user == username && pass == password),
			}

			s.writeJSONResponse(w, r, result, http.StatusOK)
		})

		r.Get("/api/json", func(w http.ResponseWriter, r *http.Request) {
			data := map[string]string{}
			for key, value := range r.URL.Query() {
				data[key] = value[0]
			}

			s.writeJSONResponse(w, r, data, http.StatusOK)
		})

		r.Get("/api/xml", func(w http.ResponseWriter, r *http.Request) {
			type param struct {
				Key   string `xml:"key"`
				Value string `xml:"value"`
				Index int    `xml:"index"`
			}
			type response struct {
				Params []param `xml:"params"`
			}
			data := []param{}
			i := 0
			for key, value := range r.URL.Query() {
				data = append(data, param{Key: key, Value: value[0], Index: i})
				i++
			}

			s.writeXMLResponse(w, r, response{Params: data}, http.StatusOK)
		})
	})
}

func (s *Server) AuthViaCatalogClientMiddleware(catalogClient CatalogClient) func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			// Copy the Authorization header into the context, so that when making
			// requests to other QP microservices, the header is forwarded to them
			// (see code in client.go).
			auth := requestTokenFromCookie(r)
			if auth != "" {
				s.log.DebugContext(r.Context(), "Taking auth info from cookies")
				r.Header.Set(authHeader, "Token "+auth)
			}

			ctx := context.WithValue(r.Context(), authKey, r.Header.Get(authHeader))

			user, err := catalogClient.WithRequestContext(ctx).Authenticate()
			if err != nil {
				s.writeJSONErrorResponse(w, r, authError, http.StatusUnauthorized)
				return
			}

			ctx = context.WithValue(ctx, userKey, user)
			next.ServeHTTP(w, r.WithContext(ctx))
		})
	}
}

func (s *Server) AuthMiddleware(db *database.Catalog) func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			token := getRequestToken(r)
			if token == "" {
				s.writeJSONErrorResponse(w, r, authError, http.StatusUnauthorized)
				return
			}
			user, err := db.Authenticate(r.Context(), token)
			if err != nil {
				s.writeJSONErrorResponse(w, r, authError, http.StatusUnauthorized)
				return
			}

			ctx := context.WithValue(r.Context(), userKey, user)
			next.ServeHTTP(w, r.WithContext(ctx))
		})
	}
}

// AddCatalogHandler enables routes related to the ingredients, doughs, tools, ratings and users.
// A database.InMemoryDatabase is required to enable this endpoint group.
// This database is safe to be used concurrently and thus may be shared with other endpoint groups.
func (s *Server) AddCatalogHandler(db *database.Catalog) {
	s.router.Group(func(r chi.Router) {
		s.traceInstaller.Install(r, "catalog")

		r.Use(s.AuthMiddleware(db))
		r.Use(LogUser)
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

			s.log.DebugContext(r.Context(), "Ingredients requested", "type", ingredientType)

			s.writeJSONResponse(w, r, map[string][]model.Ingredient{"ingredients": ingredients}, http.StatusOK)
		})

		r.Get("/api/doughs", func(w http.ResponseWriter, r *http.Request) {
			s.log.DebugContext(r.Context(), "Doughs requested")

			doughs, err := db.GetDoughs(r.Context())
			if err != nil {
				s.log.ErrorContext(r.Context(), "Failed to get doughs from database", "err", err)
				w.WriteHeader(http.StatusInternalServerError)
				return
			}

			s.writeJSONResponse(w, r, map[string][]model.Dough{"doughs": doughs}, http.StatusOK)
		})

		r.Get("/api/tools", func(w http.ResponseWriter, r *http.Request) {
			s.log.DebugContext(r.Context(), "Tools requested")

			tools, err := db.GetTools(r.Context())
			if err != nil {
				s.log.ErrorContext(r.Context(), "Failed to get tools from database", "err", err)
				w.WriteHeader(http.StatusInternalServerError)
				return
			}

			s.writeJSONResponse(w, r, map[string][]string{"tools": tools}, http.StatusOK)
		})

		// Rating CRUD endpoints
		r.Post("/api/ratings", func(w http.ResponseWriter, r *http.Request) {
			user := contextUser(r.Context())
			if user == nil {
				s.writeJSONErrorResponse(w, r, authError, http.StatusUnauthorized)
				return
			}

			var rating model.Rating
			if err := s.decodeJSONBody(w, r, &rating); err != nil {
				return
			}

			if err := rating.Validate(); err != nil {
				s.writeJSONErrorResponse(w, r, err, http.StatusBadRequest)
				return
			}

			rating.UserID = user.ID

			if err := db.RecordRating(r.Context(), &rating); err != nil {
				s.writeJSONErrorResponse(w, r, err, http.StatusBadRequest)
				return
			}

			s.writeJSONResponse(w, r, rating, http.StatusCreated)
		})

		r.Get("/api/ratings/{id:\\d+}", func(w http.ResponseWriter, r *http.Request) {
			idParam, err := strconv.Atoi(chi.URLParam(r, "id"))
			if err != nil {
				w.WriteHeader(http.StatusBadRequest)
				return
			}

			user := contextUser(r.Context())
			if user == nil {
				s.writeJSONErrorResponse(w, r, authError, http.StatusUnauthorized)
				return
			}

			rating, err := db.GetRating(r.Context(), user, idParam)
			if err != nil {
				s.writeJSONErrorResponse(w, r, err, http.StatusBadRequest)
				return
			} else if rating == nil {
				s.writeJSONErrorResponse(w, r, errors.New("not found"), http.StatusNotFound)
				return
			}

			s.writeJSONResponse(w, r, rating, http.StatusOK)
		})

		r.Get("/api/ratings", func(w http.ResponseWriter, r *http.Request) {
			user := contextUser(r.Context())
			if user == nil {
				s.writeJSONErrorResponse(w, r, authError, http.StatusUnauthorized)
				return
			}

			ratings, err := db.GetRatings(r.Context(), user)
			if err != nil {
				s.writeJSONErrorResponse(w, r, err, http.StatusBadRequest)
				return
			}

			s.writeJSONResponse(w, r, map[string]any{"ratings": ratings}, http.StatusOK)
		})

		updateRating := func(w http.ResponseWriter, r *http.Request) {
			idParam, err := strconv.Atoi(chi.URLParam(r, "id"))
			if err != nil {
				w.WriteHeader(http.StatusBadRequest)
				return
			}

			user := contextUser(r.Context())
			if user == nil {
				s.writeJSONErrorResponse(w, r, authError, http.StatusUnauthorized)
				return
			}

			var rating model.Rating
			if err := s.decodeJSONBody(w, r, &rating); err != nil {
				return
			}

			if err := rating.Validate(); err != nil {
				s.writeJSONErrorResponse(w, r, err, http.StatusBadRequest)
				return
			}

			rating.ID = int64(idParam)

			updated, err := db.UpdateRating(r.Context(), user, &rating)
			if err != nil {
				if errors.Is(err, database.ErrGlobalOperationNotPermitted) {
					s.writeJSONErrorResponse(w, r, err, http.StatusForbidden)
				} else {
					s.writeJSONErrorResponse(w, r, err, http.StatusBadRequest)
				}
				return
			}

			s.writeJSONResponse(w, r, updated, http.StatusOK)
		}

		r.Post("/api/users/token/logout", func(w http.ResponseWriter, r *http.Request) {
			http.SetCookie(w, &http.Cookie{
				Name:     qpUserTokenCookie,
				Value:    "",
				SameSite: http.SameSiteStrictMode,
				Path:     "/",
				Expires:  time.Unix(0, 0),
			})

			w.WriteHeader(http.StatusOK)
		})

		r.Put("/api/ratings/{id:\\d+}", updateRating)
		r.Patch("/api/ratings/{id:\\d+}", updateRating)

		r.Delete("/api/ratings", func(w http.ResponseWriter, r *http.Request) {
			user := contextUser(r.Context())
			if user == nil {
				s.writeJSONErrorResponse(w, r, authError, http.StatusUnauthorized)
				return
			}

			err := db.DeleteRatings(r.Context(), user)
			if err != nil {
				if errors.Is(err, database.ErrGlobalOperationNotPermitted) {
					s.writeJSONErrorResponse(w, r, err, http.StatusForbidden)
				} else {
					s.writeJSONErrorResponse(w, r, err, http.StatusBadRequest)
				}
				return
			}

			w.WriteHeader(http.StatusNoContent)
		})

		r.Delete("/api/ratings/{id:\\d+}", func(w http.ResponseWriter, r *http.Request) {
			idParam, err := strconv.Atoi(chi.URLParam(r, "id"))
			if err != nil {
				w.WriteHeader(http.StatusBadRequest)
				return
			}

			user := contextUser(r.Context())
			if user == nil {
				s.writeJSONErrorResponse(w, r, authError, http.StatusUnauthorized)
				return
			}

			err = db.DeleteRating(r.Context(), user, idParam)
			if err != nil {
				if errors.Is(err, database.ErrGlobalOperationNotPermitted) {
					s.writeJSONErrorResponse(w, r, err, http.StatusForbidden)
				} else {
					s.writeJSONErrorResponse(w, r, err, http.StatusBadRequest)
				}
				return
			}

			w.WriteHeader(http.StatusNoContent)
		})
	})

	s.router.Group(func(r chi.Router) {
		s.traceInstaller.Install(r, "users")

		r.Post("/api/csrf-token", func(w http.ResponseWriter, r *http.Request) {
			http.SetCookie(w, &http.Cookie{
				Name:     csrfTokenCookie,
				Value:    util.GenerateAlphaNumToken(csrfTokenLength),
				SameSite: http.SameSiteStrictMode,
				Path:     "/",
			})
		})

		r.Post("/api/users", func(w http.ResponseWriter, r *http.Request) {
			var user model.User
			if s.decodeJSONBody(w, r, &user) != nil {
				return
			}

			if err := user.Validate(); err != nil {
				s.writeJSONErrorResponse(w, r, err, http.StatusBadRequest)
				return
			}

			err := db.RecordUser(r.Context(), &user)
			if err == database.ErrUsernameTaken {
				s.writeJSONErrorResponse(w, r, err, http.StatusBadRequest)
				return
			} else if err != nil {
				s.log.ErrorContext(r.Context(), "Failed to record user", "err", err)
				w.WriteHeader(http.StatusInternalServerError)
				return
			}

			user.Password = ""
			user.Token = ""
			s.writeJSONResponse(w, r, user, http.StatusCreated)
		})

		// Given username + password, set a Cookie with the user's
		// token, and return the user token (if credentials are valid).
		r.Post("/api/users/token/login", func(w http.ResponseWriter, r *http.Request) {
			type loginData struct {
				Username  string `json:"username"`
				Password  string `json:"password"`
				CSRFToken string `json:"csrf"`
			}
			var data loginData

			if s.decodeJSONBody(w, r, &data) != nil {
				return
			}

			setCookie := r.URL.Query().Get("set_cookie") != ""

			if setCookie {
				csrfToken := ""
				if tokenCookie, err := r.Cookie(csrfTokenCookie); err == nil {
					csrfToken = tokenCookie.Value
				}

				if csrfToken != data.CSRFToken {
					s.writeJSONErrorResponse(w, r, errors.New("invalid csrf token"), http.StatusUnauthorized)
					return
				}
			}

			user, err := db.LoginUser(r.Context(), data.Username, data.Password)
			if err != nil {
				s.log.ErrorContext(r.Context(), "Failed to login user", "err", err)
				w.WriteHeader(http.StatusInternalServerError)
				return
			}

			if user == nil {
				// User does not exist, or password auth failed.
				s.writeJSONErrorResponse(w, r, authError, http.StatusUnauthorized)
				return
			}

			if setCookie {
				// Set the QP user token cookie
				http.SetCookie(w, &http.Cookie{
					Name:     qpUserTokenCookie,
					Value:    user.Token,
					SameSite: http.SameSiteStrictMode,
					Path:     "/",
				})

				// Delete the cookie containing the CSRF token
				http.SetCookie(w, &http.Cookie{
					Name:     csrfTokenCookie,
					Value:    "",
					SameSite: http.SameSiteStrictMode,
					Path:     "/",
					Expires:  time.Unix(0, 0),
				})
			}

			s.writeJSONResponse(w, r, map[string]string{"token": user.Token}, http.StatusOK)
		})

		// Given a user token, return 200 or 401 (depending on whether token is valid).
		r.Post("/api/users/token/authenticate", func(w http.ResponseWriter, r *http.Request) {
			// This endpoint is only to be used by other QP services.
			if r.Header.Get("X-Is-Internal") == "" {
				s.writeJSONErrorResponse(w, r, authError, http.StatusUnauthorized)
				return
			}

			token := getRequestToken(r)
			if token == "" {
				s.writeJSONErrorResponse(w, r, authError, http.StatusUnauthorized)
				return
			}

			user, err := db.Authenticate(r.Context(), token)
			if err != nil {
				s.log.ErrorContext(r.Context(), "Failed to check token", "err", err)
				w.WriteHeader(http.StatusInternalServerError)
				return
			}

			s.writeJSONResponse(w, r, user, http.StatusOK)
		})
	})

	s.router.Group(func(r chi.Router) {
		// These endpoints do not have user token validation.
		s.traceInstaller.Install(r, "admin")

		r.Post("/api/internal/recommendations", func(w http.ResponseWriter, r *http.Request) {
			if r.Header.Get("X-Is-Internal") == "" {
				s.writeJSONErrorResponse(w, r, authError, http.StatusUnauthorized)
				return
			}

			var latestRecommendation model.Pizza
			if s.decodeJSONBody(w, r, &latestRecommendation) != nil {
				return
			}

			if err := db.RecordRecommendation(r.Context(), &latestRecommendation); err != nil {
				s.log.ErrorContext(r.Context(), "Failed to save recommendation", "err", err)
				w.WriteHeader(http.StatusInternalServerError)
				return
			}

			s.writeJSONResponse(w, r, latestRecommendation, http.StatusCreated)
		})

		r.Get("/api/internal/recommendations/{id:\\d+}", func(w http.ResponseWriter, r *http.Request) {
			idParam, err := strconv.Atoi(chi.URLParam(r, "id"))
			if err != nil {
				w.WriteHeader(http.StatusBadRequest)
				return
			}

			recommendation, err := db.GetRecommendation(r.Context(), idParam)
			if err != nil {
				s.log.ErrorContext(r.Context(), "Failed to fetch recommendation from db", "err", err)
				w.WriteHeader(http.StatusInternalServerError)
				return
			}

			if recommendation == nil {
				w.WriteHeader(http.StatusNotFound)
				return
			}

			s.writeJSONResponse(w, r, recommendation, http.StatusOK)
		})

		r.Get("/api/internal/recommendations", func(w http.ResponseWriter, r *http.Request) {
			s.log.DebugContext(r.Context(), "Recommendations requested")
			token := ""
			if tokenCookie, err := r.Cookie("admin_token"); err == nil {
				token = tokenCookie.Value
			}

			if token == "" {
				s.writeJSONErrorResponse(w, r, authError, http.StatusUnauthorized)
				return
			}

			history, err := db.GetHistory(r.Context(), 15)
			if err != nil {
				s.log.ErrorContext(r.Context(), "Failed to fetch history from db", "err", err)
				w.WriteHeader(http.StatusInternalServerError)
				return
			}

			s.writeJSONResponse(w, r, map[string][]model.Pizza{"pizzas": history}, http.StatusOK)
		})

		r.HandleFunc("/api/admin/login", func(w http.ResponseWriter, r *http.Request) {
			if r.Method == http.MethodGet {
				// Allow using GET for admin login, in order not to break existing examples.
				s.log.DebugContext(r.Context(), "Admin login with GET is deprecated")
			} else if r.Method != http.MethodPost {
				w.WriteHeader(http.StatusMethodNotAllowed)
				return
			}

			s.log.DebugContext(r.Context(), "Login requested")
			user := r.URL.Query().Get("user")
			password := r.URL.Query().Get("password")

			if user == "" || password == "" {
				w.WriteHeader(http.StatusBadRequest)
				return
			}

			if user != "admin" || password != "admin" {
				s.writeJSONErrorResponse(w, r, authError, http.StatusUnauthorized)
				return
			}

			guid := xid.New()
			token := guid.String()

			http.SetCookie(w, &http.Cookie{
				Name:     "admin_token",
				Value:    token,
				SameSite: http.SameSiteStrictMode,
				Path:     "/", // Required for /admin to be able to use a cookie returned by /api.
			})

			s.writeJSONResponse(w, r, map[string]string{"token": token}, http.StatusOK)
		})
	})
}

// AddCopyHandler enables copy (i.e. prose) related endpoints.
func (s *Server) AddCopyHandler(db *database.Copy) {
	s.router.Group(func(r chi.Router) {
		s.traceInstaller.Install(r, "copy")

		r.Use(errorinjector.InjectErrorHeadersMiddleware)

		// if env var is set, apply delay to all endpoints of this service
		r.Use(func(next http.Handler) http.Handler {
			return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
				util.DelayIfEnvSet("QUICKPIZZA_DELAY_COPY")
				next.ServeHTTP(w, r)
			})
		})

		r.Get("/api/quotes", func(w http.ResponseWriter, r *http.Request) {
			s.log.DebugContext(r.Context(), "Quotes requested")

			util.DelayIfEnvSet("QUICKPIZZA_DELAY_COPY_API_QUOTES")

			quotes, err := db.GetQuotes(r.Context())
			if err != nil {
				s.log.ErrorContext(r.Context(), "Failed to fetch quotes from db", "err", err)
				w.WriteHeader(http.StatusInternalServerError)
			}

			s.writeJSONResponse(w, r, map[string][]string{"quotes": quotes}, http.StatusOK)
		})

		r.Get("/api/names", func(w http.ResponseWriter, r *http.Request) {
			s.log.DebugContext(r.Context(), "Names requested")

			util.DelayIfEnvSet("QUICKPIZZA_DELAY_COPY_API_NAMES")

			names, err := db.GetClassicalNames(r.Context())
			if err != nil {
				s.log.ErrorContext(r.Context(), "Failed to fetch names from db", "err", err)
				w.WriteHeader(http.StatusInternalServerError)
			}

			s.writeJSONResponse(w, r, map[string][]string{"names": names}, http.StatusOK)
		})

		r.Get("/api/adjectives", func(w http.ResponseWriter, r *http.Request) {
			s.log.DebugContext(r.Context(), "Adjectives requested")

			util.DelayIfEnvSet("QUICKPIZZA_DELAY_COPY_API_ADJECTIVES")

			adjs, err := db.GetAdjectives(r.Context())
			if err != nil {
				s.log.ErrorContext(r.Context(), "Failed to fetch adjectives from db", "err", err)
				w.WriteHeader(http.StatusInternalServerError)
			}

			s.writeJSONResponse(w, r, map[string][]string{"adjectives": adjs}, http.StatusOK)
		})
	})
}

// AddRecommendations enables the recommendations endpoint in this Server. This endpoint is stateless and thus needs
// the URLs for the Catalog and Copy services.
func (s *Server) AddRecommendations(catalogClient CatalogClient, copyClient CopyClient) {
	s.router.Group(func(r chi.Router) {
		s.traceInstaller.Install(r, "recommendations")

		r.Use(s.AuthViaCatalogClientMiddleware(catalogClient))
		r.Use(LogUser)
		r.Use(errorinjector.InjectErrorHeadersMiddleware)

		// if env var is set, apply delay to all endpoints of this service
		r.Use(func(next http.Handler) http.Handler {
			return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
				util.DelayIfEnvSet("QUICKPIZZA_DELAY_RECOMMENDATIONS")
				next.ServeHTTP(w, r)
			})
		})

		r.Get("/api/pizza/{id:\\d+}", func(w http.ResponseWriter, r *http.Request) {

			util.DelayIfEnvSet("QUICKPIZZA_DELAY_RECOMMENDATIONS_API_PIZZA_GET")
			id, err := strconv.Atoi(chi.URLParam(r, "id"))
			if err != nil {
				w.WriteHeader(http.StatusBadRequest)
				return
			}

			pizza, err := catalogClient.GetRecommendation(id)
			if err != nil {
				s.log.ErrorContext(r.Context(), "Failed to fetch recommendation from catalog", "err", err)
				w.WriteHeader(http.StatusInternalServerError)
				return
			}

			if pizza == nil {
				w.WriteHeader(http.StatusNotFound)
				return
			}

			s.writeJSONResponse(w, r, pizza, http.StatusOK)
		})

		r.Post("/api/pizza", func(w http.ResponseWriter, r *http.Request) {

			util.DelayIfEnvSet("QUICKPIZZA_DELAY_RECOMMENDATIONS_API_PIZZA_POST")

			if util.FailRandomlyIfEnvSet("QUICKPIZZA_FAIL_RATE_RECOMMENDATIONS_API_PIZZA_POST") {
				s.log.ErrorContext(r.Context(), "Simulated random failure: Pizza service temporarily unavailable")
				s.writeJSONErrorResponse(w, r, errors.New("Pizza service temporarily unavailable"), http.StatusServiceUnavailable)
				return
			}
			// Add request context to catalog and copy clients. This context contains a reference to the tracer used
			// by the server (if any), which allows clients to both generate traces for outgoing client-type traces
			// without explicitly configuring a tracer, and to link said client traces with the server trace that is
			// generated in this request.
			catalogClient := catalogClient.WithRequestContext(r.Context())
			copyClient := copyClient.WithRequestContext(r.Context())

			tracer := trace.SpanFromContext(r.Context()).TracerProvider().Tracer("")

			s.log.DebugContext(r.Context(), "Received pizza recommendation request")
			var restrictions Restrictions
			if s.decodeJSONBody(w, r, &restrictions) != nil {
				return
			}

			restrictions = restrictions.WithDefaults()

			if len(restrictions.CustomName) > model.MaxPizzaNameLength {
				restrictions.CustomName = restrictions.CustomName[:model.MaxPizzaNameLength]
			}

			oils, err := catalogClient.Ingredients("olive_oil")
			if err != nil {
				s.log.ErrorContext(r.Context(), "Requesting ingredients", "err", err)
				w.WriteHeader(http.StatusInternalServerError)
				return
			}

			// Retrieve list of ingredients from Catalog.
			var validOliveOils []model.Ingredient
			for _, oliveOil := range oils {
				if !slices.Contains(restrictions.ExcludedIngredients, oliveOil.Name) && (!restrictions.MustBeVegetarian || oliveOil.Vegetarian) {
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
				if !slices.Contains(restrictions.ExcludedIngredients, tomato.Name) && (!restrictions.MustBeVegetarian || tomato.Vegetarian) {
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
				if !slices.Contains(restrictions.ExcludedIngredients, mozzarella.Name) && (!restrictions.MustBeVegetarian || mozzarella.Vegetarian) {
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
				if !slices.Contains(restrictions.ExcludedIngredients, topping.Name) && (!restrictions.MustBeVegetarian || topping.Vegetarian) {
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
				if !slices.Contains(restrictions.ExcludedTools, tool) {
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
			for range 10 {
				randomName := restrictions.CustomName

				if randomName == "" {
					_, nameSpan := tracer.Start(pizzaCtx, "name-generation")

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
				}

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

				for range extraToppings + restrictions.MinNumberOfToppings {
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

			result, err := catalogClient.RecordRecommendation(p)
			if err != nil {
				s.log.ErrorContext(r.Context(), "Storing recommendation in catalog", "err", err)
				w.WriteHeader(http.StatusInternalServerError)
				return
			}

			// Update the .Pizza property we received from calling the catalog client.
			// This allows us to return the generated pizza's ID to the client.
			pizzaRecommendation.Pizza = *result

			pizzaRecommendations.With(prometheus.Labels{
				"vegetarian": strconv.FormatBool(pizzaRecommendation.Vegetarian),
				"tool":       pizzaRecommendation.Pizza.Tool,
			}).Inc()

			numberOfIngredientsPerPizza.Observe(float64(len(p.Ingredients)))
			numberOfIngredientsPerPizzaNativeHistogram.Observe(float64(len(p.Ingredients)))
			pizzaCaloriesPerSlice.Observe(float64(pizzaRecommendation.Calories))
			pizzaCaloriesPerSliceNativeHistogram.Observe(float64(pizzaRecommendation.Calories))

			s.log.InfoContext(r.Context(), "New pizza recommendation", "pizza", pizzaRecommendation.Pizza.Name)
			s.writeJSONResponse(w, r, pizzaRecommendation, http.StatusOK)
		})
	})
}

func FaviconHandler() http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		data, _ := web.Static.ReadFile("static/favicon.ico")
		w.WriteHeader(http.StatusOK)
		w.Write(data)
	})
}

// From: https://www.liip.ch/en/blog/embed-sveltekit-into-a-go-binary
func SvelteKitHandler() http.Handler {
	fsys, err := fs.Sub(web.EmbeddedFiles, "build")
	if err != nil {
		log.Fatal(err)
	}
	filesystem := http.FS(fsys)

	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		path := r.URL.Path

		// Delay CSS resources
		if strings.HasSuffix(strings.ToLower(path), ".css") {
			util.DelayIfEnvSet("QUICKPIZZA_DELAY_FRONTEND_CSS_ASSETS")
		}
		if strings.HasSuffix(strings.ToLower(path), ".png") {
			util.DelayIfEnvSet("QUICKPIZZA_DELAY_FRONTEND_PNG_ASSETS")
		}

		// try if file exists at path, if not append .html (SvelteKit adapter-static specific)
		_, err := filesystem.Open(path)
		if errors.Is(err, os.ErrNotExist) {
			path = fmt.Sprintf("%s.html", path)
		}
		r.URL.Path = path
		http.FileServer(filesystem).ServeHTTP(w, r)
	})
}

func PrometheusMiddleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		start := time.Now()
		ww := middleware.NewWrapResponseWriter(w, r.ProtoMajor)
		next.ServeHTTP(ww, r)
		duration := time.Since(start)

		pattern := chi.RouteContext(r.Context()).RoutePattern()

		httpRequests.WithLabelValues(r.Method, pattern, strconv.Itoa(ww.Status())).Inc()
		httpRequestDuration.WithLabelValues(r.Method, pattern, strconv.Itoa(ww.Status())).Observe(duration.Seconds())
	})
}
