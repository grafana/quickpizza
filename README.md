# QuickPizza

![QuickPizza screenshot](./docs/images/quickpizza-screenshot.png)

## What is QuickPizza? 🍕🍕🍕

`QuickPizza` is a web application, used for demonstrations and workshops, that generates new and exciting pizza combinations!

The app is built using [SvelteKit](https://kit.svelte.dev/) for the frontend and [Go](https://go.dev/) for the backend.

The tests written for `QuickPizza` demonstrates the basic and advanced functionalities of k6, ranging from a basic load test to using different modules and extensions. QuickPizza is used in the the [k6-oss-workshop](https://github.com/grafana/k6-oss-workshop).

## Requirements

- [Docker](https://docs.docker.com/get-docker/)
- [Grafana k6](https://grafana.com/docs/k6/latest/set-up/install-k6/) (v.0.46.0 or higher)

## Run locally with Docker

To run the app locally with Docker, run the command:

```bash
docker run --rm -it -p 3333:3333  ghcr.io/grafana/quickpizza-local:latest
```

or build image from the repo:

```bash
docker run --rm -it -p 3333:3333 $(docker build -q .)
```

That's it!

Now you can go to [localhost:3333](http://localhost:3333) and get some pizza recommendations!

## Use k6 to test QuickPizza

All tests live in the `k6` folder. Within this folder, you will find the following folders:

- [foundations](k6/foundations/) - covers the basic functionalities of k6.
- [browser](k6/browser/) - covers the [k6 browser module](https://grafana.com/docs/k6/latest/using-k6-browser/) for browser and web performance testing.
- [extensions](k6/extensions/) - covers basic tests using [k6 extensions](https://grafana.com/docs/k6/latest/extensions/).
- [disruptor](k6/disruptor/) - covers a more deep-dive look on how to use [xk6-disruptor](https://grafana.com/docs/k6/latest/testing-guides/injecting-faults-with-xk6-disruptor/first-steps/) for failure injection testing.

To run tests on the `foundations` folder, you can use the following commands:

```bash
cd k6/foundations
k6 run 01.basic.js
```

If you want to run one iteration with one virtual user, you can use the following command:

```bash
k6 run --iterations 1 --vus 1 01.basic.js
```

If QuickPizza is [deployed remotely](#deploy-quickpizza-docker-image), then pass the hostname and port through the `BASE_URL` environment variable as follows:

```bash
k6 run -e BASE_URL=https://acmecorp.dev:3333 01.basic.js
```

<details>
  <summary>Using k6 extensions</summary>
  If the test uses an extension, you need to build a k6 binary that includes the required extension/s. For detailed instructions, refer to k6 docs:

  - [Build a k6 binary using Go](https://grafana.com/docs/k6/latest/extensions/build-k6-binary-using-go/)
  - [Build a k6 binary using Docker](https://grafana.com/docs/k6/latest/extensions/build-k6-binary-using-docker/)

  ```bash
  cd k6/extensions

  xk6 build --with xk6-internal=../internal
  ```

  To run the test that uses the `k6/x/internal` module, use  previously created k6 binary in the `k6/extensions` folder:

  ```bash
  ./k6 run 01.basic-internal.js
  ```
</details>

<details>
  <summary>Using k6 Docker image</summary>
  If you want to use the [k6 Docker image](https://hub.docker.com/r/grafana/k6) to run k6, you need to run the Quickpizza and k6 containers within the same network.

  First, create a Docker network. Then, run Quickpizza, assigning a hostname and connecting to the created network.

  ```bash
  docker network create quickpizza_network
  docker run --network=quickpizza_network --hostname=quickpizza --rm -it -p 3333:3333  ghcr.io/grafana/quickpizza-local:latest
  ```

  Next, you can use the k6 Docker image to execute the k6 test. Run the k6 Docker container within the same network (`quickpizza_network`) and pass the `BASE_URL` environment variable with the value of the Quickpizza container's hostname as follows:

  ```bash
  docker run -i --network=quickpizza_network -e BASE_URL=http://quickpizza:3333 grafana/k6 run  - <01.basic.js
  ```
</details>


## Collect telemetry (Docker Compose)

Testing something you can't observe is only half the fun. QuickPizza is instrumented using best practices to record logs, emit metrics, traces and allow profiling. You can either collect and [store this data locally](#local-setup) or send it to [Grafana Cloud](#grafana-cloud).

## Enabling debug logging

If you encounter any issues during operation, you can enable debug logging by setting the following evironment variable:

```shell
export QUICKPIZZA_LOG_LEVEL=debug
```

## Running a Prometheus instance

### Local Setup

The [docker-compose-local.yaml](./docker-compose-local.yaml) file is set up to run and orchestrate the QuickPizza, Grafana, Tempo, Loki, Prometheus, Pyroscope, and Grafana Agent containers.

The Grafana Agent collects traces, metrics, logs and profiling data from the QuickPizza app, forwarding them to the Tempo, Prometheus and Loki. Finally, you can visualize and correlate data stored in these containers with the locally running Grafana instance.

To start the local environment, use the following command:

```bash
docker compose -f docker-compose-local.yaml up -d
```

Like before, QuickPizza is available at [localhost:3333](http://localhost:3333). It's time to discover some fancy pizzas!

Then, you can visit the Grafana instance running at [localhost:3000](http://localhost:3000) to access QuickPizza data.

Please refer to [agent-local.river](./contrib/agent-local.river) and [docker-compose-local.yaml](./docker-compose-local.yaml) to find the labels applied to the telemetry data.

**Correlate Pyroscope data with k6 tests**

Whenever there is a Pyroscope instance endpoint provided via `QUICKPIZZA_PYROSCOPE_ENDPOINT` environment variable, the QuickPizza app will emit profiling data to Pyroscope. You can visualize the profiling data with the Pyroscope data source in Grafana.

To correlate the profiling data with the k6 test results, use the [k6 Pyroscope library](https://grafana.com/docs/k6/next/javascript-api/jslib/http-instrumentation-pyroscope/).

![Pyroscope Data Source](./docs/images/local-env-grafana-with-pyroscope.png)

Additional variables are available to configure the Pyroscope data source:
- `QUICKPIZZA_PYROSCOPE_NAME` - the name of the service in Pyroscope (uses `quickpizza` by default)
- `QUICKPIZZA_GRAFANA_CLOUD_USER` and `QUICKPIZZA_GRAFANA_CLOUD_PASSWORD` are the Basic auth credentials to authenticate with the Grafana Cloud instance.

**Send k6 results to Prometheus and visualize them with prebuilt dashboards**

To send k6 results to the Prometheus instance, execute the `k6 run` command with the value of the `output` flag set to `experimental-prometheus-rw` as follows:

```bash
k6 run -o experimental-prometheus-rw 01.basic.js
```

The local Grafana instance includes the [k6 Prometheus](https://grafana.com/grafana/dashboards/19665-k6-prometheus/) and [k6 Prometheus (Native Histogram)](https://grafana.com/grafana/dashboards/18030-k6-prometheus-native-histograms/) dashboards to help visualize, query, and correlate k6 results with telemetry data.

![k6 provisioned dashboards](./docs/images/provisioned-k6-prometheus-dashboards.png)

For detailed instructions about the different options of the k6 Prometheus output, refer to the [k6 output guide for Prometheus remote write](https://grafana.com/docs/k6/latest/results-output/real-time/prometheus-remote-write/).


### Grafana Cloud

The [docker-compose-cloud.yaml](./docker-compose-cloud.yaml) file is set up to run the QuickPizza and Grafana Agent containers.

In this setup, the Grafana Agent collects observability data from the QuickPizza app and forwards it to [Grafana Cloud](https://grafana.com/products/cloud/).

You will need the following settings:
1. The name of the [Grafana Cloud Stack](https://grafana.com/docs/grafana-cloud/account-management/cloud-portal/#your-grafana-cloud-stack) where the telemetry data will be stored.
2. An [Access Policy Token](https://grafana.com/docs/grafana-cloud/account-management/authentication-and-permissions/access-policies/) that includes the following scopes for the selected Grafana Cloud Stack: `stacks:read`, `metrics:write`, `logs:write`, `traces:write`, and `profiles:write`.

Then, create an `.env` file with the following environment variables and the values of the previous settings:

```bash
GRAFANA_CLOUD_STACK=name
GRAFANA_CLOUD_TOKEN=
```

Finally, execute the Docker Compose command using the `docker-compose-cloud.yaml` file, just as in the local setup:

```bash
docker compose -f docker-compose-cloud.yaml up -d
```

QuickPizza is available at [localhost:3333](http://localhost:3333). Click the `Pizza, Please!` button and discover some awesome pizzas!

Now, you can log in to [Grafana Cloud](https://grafana.com/products/cloud/) and explore QuickPizza's telemetry data on the Prometheus, Tempo, Loki, and Pyroscope instances of your Grafana Cloud Stack. Refer to [agent-cloud.river](./contrib/agent-cloud.river) and [docker-compose-cloud.yaml](./docker-compose-cloud.yaml) to find the labels applied to the telemetry data.

***Enable profiling (Grafana Pyroscope)***

To enable [Grafana Cloud Profiling](https://grafana.com/docs/grafana-cloud/monitor-applications/profiles/), add the `QUICKPIZZA_CONF_PYROSCOPE_URL` variable to the `.env` file, setting its value to your Pyroscope web URL:

```bash
QUICKPIZZA_CONF_PYROSCOPE_URL=
```

Restart the `docker-compose-cloud.yaml` environment.

***Enable Frontend observability (Grafana Faro)***

Frontend observability is available exclusively in Grafana Cloud. To enable [Grafana Cloud Frontend Observability](https://grafana.com/docs/grafana-cloud/monitor-applications/frontend-observability/) for QuickPizza, add the `QUICKPIZZA_CONF_FARO_URL` variable to the `.env` file, setting its value to your Faro web URL:

```bash
QUICKPIZZA_CONF_FARO_URL=
```

Restart the `docker-compose-cloud.yaml` environment.

![Frontend Observability](./docs/images/grafana-cloud-frontend-observability.png)

**Send k6 results to Grafana Cloud Prometheus and visualize them with prebuilt dashboards**

Just like in the local setup, we can output k6 result metrics to a Prometheus instance; in this case, it is provided by our Grafana Cloud Stack.

```bash
K6_PROMETHEUS_RW_USERNAME=USERNAME \
K6_PROMETHEUS_RW_PASSWORD=API_KEY \
K6_PROMETHEUS_RW_SERVER_URL=REMOTE_WRITE_ENDPOINT \
k6 run -o experimental-prometheus-rw script.js
```

For detailed instructions, refer to the [k6 output guide for Grafana Cloud Prometheus](https://grafana.com/docs/k6/latest/results-output/real-time/grafana-cloud-prometheus/).

## Deploy QuickPizza Docker image

The [Dockerfile](./Dockerfile) contains the setup for running QuickPizza without collecting data with the Grafana agent.

You can use the Dockerfile or build a Docker image to deploy the QuickPizza app on any cloud provider that supports Docker deployments. For simplicity, here are the `Fly.io` instructions:

1. [Authenticate using the fly CLI](https://fly.io/docs/speedrun/).
2. Then, run the CLI to deploy the application and set up the internal port `3333` that the server listens to.
    ```bash
    fly launch --internal-port 3333 --now
    ```

For deployments on remote servers, you need to pass the `BASE_URL` environment variable when running the k6 tests as follows:

```bash
k6 run -e BASE_URL=https://acmecorp.dev:3333 01.basic.js
```

## Use an external database

By default, QuickPizza stores all its data in an in-memory SQLite database. This allows for a quick start while still closely resembling a real world application. If you want to add an external database, you can set the `QUICKPIZZA_DB` environment variable to a supported connection string. Currently only PostgreSQL and SQLite is supported.

Example connection strings:
```shell
# a remote PostgreSQL instance
export QUICKPIZZA_DB="postgres://user:password@localhost:5432/database?sslmode=disable"
# a local sqlite3 database
export QUICKPIZZA_DB="quickpizza.db"
```

## Deploy application to Kubernetes

If you want to run a test that uses [xk6-disruptor](https://grafana.com/docs/k6/latest/testing-guides/injecting-faults-with-xk6-disruptor/first-steps/), or want to experiment with distributed tracing, you will need to deploy QuickPizza to Kubernetes.

For a detailed setup instructions, see the [QuickPizza Kubernetes guide](./docs/kubernetes-setup.md).

## Injecting Errors from Client via Headers
You can introduce errors from the client side using custom headers. Below is a list of the currently supported error headers:

- **x-error-record-recommendation**: Triggers an error when recording a recommendation. The header value should be the error message.
- **x-error-record-recommendation-percentage**: Specifies the percentage chance of an error occurring when recording a recommendation, if x-error-record-recommendation is also included. The header value should be a number between 0 and 100.
- **x-delay-record-recommendation**: Introduces a delay when recording a recommendation. The header value should specify the delay duration and unit. Valid time units are "ns", "us" (or "µs"), "ms", "s", "m", "h", "d", "w", "y".
- **x-delay-record-recommendation-percentage**: Specifies the percentage chance of a delay occurring when recording a recommendation, if x-delay-record-recommendation is also included. The header value should be a number between 0 and 100.
- **x-error-get-ingredients**: Triggers an error when retrieving ingredients. The header value should be the error message.
- **x-error-get-ingredients-percentage**: Specifies the percentage chance of an error occurring when retrieving ingredients, if x-error-get-ingredients is also included. The header value should be a number between 0 and 100.
- **x-delay-get-ingredients**: Introduces a delay when retrieving ingredients. The header value should specify the delay duration and unit. Valid time units are "ns", "us" (or "µs"), "ms", "s", "m", "h", "d", "w", "y".
- **x-delay-get-ingredients-percentage**: Specifies the percentage chance of a delay occurring when retrieving ingredients, if x-delay-get-ingredients is also included. The header value should be a number between 0 and 100.

Example of header usage:

```
curl -X POST http://localhost:3333/api/pizza \
     -H "Content-Type: application/json" \
     -H "X-User-ID: 23423" \
     -H "x-error-record-recommendation: internal-error" \
     -H "x-error-record-recommendation-percentage: 20" \
     -d '{}'
```
