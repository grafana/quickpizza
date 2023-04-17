# QuickPizza

![Screenshot from 2023-03-18 15-29-05](https://user-images.githubusercontent.com/8228060/226112255-fe2d4cdc-193e-4c23-8a36-3d8f60baaf03.png)

## How to run it

Requirements:
- Docker

```bash
docker run -it -p 3333:3333  ghcr.io/grafana/quickpizza-local:latest
```

That's it. Now you can go to localhost:3333 and get some pizza recommendations!

## Using k6 to test it

Requirements:
- Grafana k6 (v.0.43.1 or higher)

All tests live in the `k6` folder. To run them, you can use the `k6 run` command:

```bash
cd k6; k6 run 01.basic.js
```

If you want to run one iteration with one virtual user, you can use the following command:

```bash
k6 run --iterations 1 --vus 1 01.basic.js
```

If the test uses the Browser API, you need to pass the `K6_BROWSER_ENABLED=true` environment variable:

```bash
K6_BROWSER_ENABLED=true k6 run --iterations 1 --vus 1 browser.js
```

If the test uses the Extension, you need to build it first:

```bash
xk6 build --with xk6-internal=.
```

### Running a Prometheus instance

If you want to stream the metrics to a Prometheus instance, you need, well, a Prometheus instance. You can use the following command to run a local one:

```bash
docker run -p 9090:9090 prom/prometheus --config.file=/etc/prometheus/prometheus.yml \
             --storage.tsdb.path=/prometheus \
             --web.console.libraries=/usr/share/prometheus/console_libraries \
             --web.console.templates=/usr/share/prometheus/consoles \
             --web.enable-remote-write-receiver
```