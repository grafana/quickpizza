# k6 Extensions

Examples using [k6 extensions](https://grafana.com/docs/k6/latest/extensions/). Some tests require a custom k6 binary built with [xk6](https://github.com/grafana/xk6); others use automatic module resolution and run with the standard k6 binary.

## Prerequisites

Install xk6:

```bash
go install go.k6.io/xk6/cmd/xk6@latest
```

## 01. QuickPizza Extension (`01.quickpizzaext.js`)

Tests pizza recommendations against custom restrictions using a local Go extension (`quickpizzaext`).

**Build the custom k6 binary:**

```bash
xk6 build --output k6/extensions/k6 \
  --with github.com/grafana/quickpizza/extensions/quickpizzaext=./k6/extensions/quickpizzaext \
  --replace github.com/grafana/quickpizza=.
```

**Run the test:**

```bash
./k6/extensions/k6 run k6/extensions/01.quickpizzaext.js
```

## 02. Prometheus Remote Write (`02.prometheus-client.js`)

Load-tests a Prometheus remote write endpoint using [xk6-client-prometheus-remote](https://github.com/grafana/xk6-client-prometheus-remote).

**Build the custom k6 binary:**

```bash
xk6 build --output k6/extensions/k6 \
  --with github.com/grafana/xk6-client-prometheus-remote@latest
```

**Run the test:**

```bash
./k6/extensions/k6 run k6/extensions/02.prometheus-client.js
```

By default the test targets `http://localhost:9090/api/v1/write`. Override with:

```bash
./k6/extensions/k6 run k6/extensions/02.prometheus-client.js -e RW_URL=http://your-prometheus:9090/api/v1/write
```

## 03. PostgreSQL (`03.postgresql.js`)

Runs read and write load scenarios directly against the QuickPizza PostgreSQL database using [xk6-sql](https://github.com/grafana/xk6-sql). This test uses [automatic module resolution](https://grafana.com/docs/k6/latest/extensions/run/) — no custom binary needed.

**Prerequisites:** a running PostgreSQL instance seeded with the QuickPizza schema. Start one with:

```bash
docker compose -f compose.grafana-local-stack.monolithic.yaml up postgres -d
```

**Run the test:**

```bash
k6 run k6/extensions/03.postgresql.js
```

By default the test connects to `postgres://postgres:postgres@localhost:5432/quickpizza_db`. Override with the `PGCONN` environment variable by editing the connection string at the top of the file.
