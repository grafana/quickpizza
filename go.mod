module github.com/grafana/quickpizza

go 1.22

toolchain go1.23.3

require (
	github.com/go-chi/chi v1.5.4
	github.com/go-chi/cors v1.2.1
	github.com/grafana/pyroscope-go v1.1.1
	github.com/grafana/pyroscope-go/x/k6 v0.0.0-20240618140011-f1a626fc4fe0
	github.com/hashicorp/go-retryablehttp v0.7.4
	github.com/olahol/melody v1.1.3
	github.com/prometheus/client_golang v1.20.5
	github.com/rs/xid v1.4.0
	github.com/samber/slog-multi v1.2.4
	github.com/uptrace/bun v1.1.14
	github.com/uptrace/bun/dbfixture v1.1.14
	github.com/uptrace/bun/dialect/pgdialect v1.1.14
	github.com/uptrace/bun/dialect/sqlitedialect v1.1.14
	github.com/uptrace/bun/driver/pgdriver v1.1.14
	github.com/uptrace/bun/driver/sqliteshim v1.1.14
	github.com/uptrace/bun/extra/bunotel v1.1.14
	go.opentelemetry.io/contrib/bridges/otelslog v0.7.0
	go.opentelemetry.io/contrib/instrumentation/net/http/otelhttp v0.42.0
	go.opentelemetry.io/contrib/processors/baggagecopy v0.5.0
	go.opentelemetry.io/otel v1.32.0
	go.opentelemetry.io/otel/exporters/otlp/otlplog/otlploghttp v0.8.0
	go.opentelemetry.io/otel/exporters/otlp/otlpmetric/otlpmetricgrpc v1.32.0
	go.opentelemetry.io/otel/exporters/otlp/otlpmetric/otlpmetrichttp v1.32.0
	go.opentelemetry.io/otel/exporters/otlp/otlptrace v1.28.0
	go.opentelemetry.io/otel/exporters/otlp/otlptrace/otlptracegrpc v1.28.0
	go.opentelemetry.io/otel/exporters/otlp/otlptrace/otlptracehttp v1.28.0
	go.opentelemetry.io/otel/log v0.8.0
	go.opentelemetry.io/otel/sdk v1.32.0
	go.opentelemetry.io/otel/sdk/log v0.8.0
	go.opentelemetry.io/otel/sdk/metric v1.32.0
	go.opentelemetry.io/otel/trace v1.32.0
	golang.org/x/net v0.30.0
	google.golang.org/grpc v1.67.1
	google.golang.org/protobuf v1.35.1
)

require (
	github.com/munnerz/goautoneg v0.0.0-20191010083416-a7dc8b61c822 // indirect
	github.com/samber/lo v1.47.0 // indirect
)

require (
	github.com/beorn7/perks v1.0.1 // indirect
	github.com/cenkalti/backoff/v4 v4.3.0 // indirect
	github.com/cespare/xxhash/v2 v2.3.0 // indirect
	github.com/dustin/go-humanize v1.0.1 // indirect
	github.com/felixge/httpsnoop v1.0.3 // indirect
	github.com/go-logr/logr v1.4.2 // indirect
	github.com/go-logr/stdr v1.2.2 // indirect
	github.com/google/uuid v1.6.0 // indirect
	github.com/gorilla/websocket v1.5.0 // indirect
	github.com/grafana/pyroscope-go/godeltaprof v0.1.7 // indirect
	github.com/grpc-ecosystem/grpc-gateway/v2 v2.23.0 // indirect
	github.com/hashicorp/go-cleanhttp v0.5.2 // indirect
	github.com/jinzhu/inflection v1.0.0 // indirect
	github.com/kballard/go-shellquote v0.0.0-20180428030007-95032a82bc51 // indirect
	github.com/klauspost/compress v1.17.9 // indirect
	github.com/mattn/go-isatty v0.0.19 // indirect
	github.com/mattn/go-sqlite3 v1.14.17 // indirect
	github.com/prometheus/client_model v0.6.1 // indirect
	github.com/prometheus/common v0.60.1 // indirect
	github.com/prometheus/procfs v0.15.1 // indirect
	github.com/remyoudompheng/bigfft v0.0.0-20230129092748-24d4a6f8daec // indirect
	github.com/tmthrgd/go-hex v0.0.0-20190904060850-447a3041c3bc // indirect
	github.com/uptrace/opentelemetry-go-extra/otelsql v0.2.1 // indirect
	github.com/vmihailenco/msgpack/v5 v5.3.5 // indirect
	github.com/vmihailenco/tagparser/v2 v2.0.0 // indirect
	go.opentelemetry.io/otel/exporters/otlp/otlplog/otlploggrpc v0.8.0
	go.opentelemetry.io/otel/metric v1.32.0
	go.opentelemetry.io/proto/otlp v1.3.1 // indirect
	golang.org/x/crypto v0.28.0 // indirect
	golang.org/x/mod v0.18.0 // indirect
	golang.org/x/sync v0.9.0 // indirect
	golang.org/x/sys v0.27.0 // indirect
	golang.org/x/text v0.20.0 // indirect
	golang.org/x/tools v0.22.0 // indirect
	google.golang.org/genproto/googleapis/api v0.0.0-20241104194629-dd2ea8efbc28 // indirect
	google.golang.org/genproto/googleapis/rpc v0.0.0-20241104194629-dd2ea8efbc28 // indirect
	gopkg.in/yaml.v3 v3.0.1 // indirect
	lukechampine.com/uint128 v1.3.0 // indirect
	mellium.im/sasl v0.3.1 // indirect
	modernc.org/cc/v3 v3.40.0 // indirect
	modernc.org/ccgo/v3 v3.16.13 // indirect
	modernc.org/libc v1.22.6 // indirect
	modernc.org/mathutil v1.5.0 // indirect
	modernc.org/memory v1.5.0 // indirect
	modernc.org/opt v0.1.3 // indirect
	modernc.org/sqlite v1.22.1 // indirect
	modernc.org/strutil v1.1.3 // indirect
	modernc.org/token v1.1.0 // indirect
)
