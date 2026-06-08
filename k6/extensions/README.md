# k6 Extensions

Examples using [k6 extensions](https://grafana.com/docs/k6/latest/extensions/) that require a custom k6 binary built with [xk6](https://github.com/grafana/xk6).

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
  --with github.com/grafana/quickpizza/extensions/quickpizzaext=./k6/extensions/quickpizzaext
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
