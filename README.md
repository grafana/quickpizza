# QuickPizza

![Screenshot from 2023-03-18 15-29-05](https://user-images.githubusercontent.com/8228060/226112255-fe2d4cdc-193e-4c23-8a36-3d8f60baaf03.png)

This project contains an awesome application called `QuickPizza` and also demonstrates how to use the different features of k6. 

You'll find sample tests about:

- Basic HTTP load test
- Stages and lifecycles in k6
- Scenarios in k6
- Browser testing via k6 browser
- Hybrid performance test (HTTP + xk6-disruptor, browser + xk6-disruptor)
- and many more!

This can be used for demonstrations or workshops.

## Requirements

- [Docker](https://docs.docker.com/get-docker/)
- [Grafana k6](https://k6.io/docs/get-started/installation/) (v.0.43.1 or higher)

If you are running the xk6-disruptor test, Kubernetes needs to be setup and `minikube` to be downloaded. 

- [Minikube](https://minikube.sigs.k8s.io/docs/start/)

## Run locally with Docker

To run the app locally with Docker, run the command:

```bash
docker run -it -p 3333:3333  ghcr.io/grafana/quickpizza-local:latest
```

That's it!

Now you can go to [localhost:3333](http://localhost:3333) and get some pizza recommendations!

## Using k6 to test it

All tests live in the `k6/tests` folder. Within this folder, you will find the following folders:

- [mainTrack](k6/tests/mainTrack/) - covers the basic functionalities of k6.
- [browser](k6/tests/browser/) - covers a more deep-dive look on how to use the k6 browser module for browser and web performance testing.
- [disruptor](k6/tests/disruptor/) - covers a more deep-dive look on how to use xk6-disruptor for failure injection testing.
- [hybrid](k6/tests/hybrid/) - covers tests that demonstrates a hybrid performance test.

To run them, you can use the `k6 run` command:

```bash
cd k6/tests/mainTrack 
k6 run 01.basic.js
```

If you want to run one iteration with one virtual user, you can use the following command:

```bash
k6 run --iterations 1 --vus 1 01.basic.js
```

If QuickPizza is available remotely, then pass the hostname and port through the `BASE_URL` environment variable as follows:

```bash
k6 run -e BASE_URL=https://acmecorp.dev 01.basic.js
# or 
k6 run -e BASE_URL=https://acmecorp.dev:3333 01.basic.js
```

If the test uses the [browser module](https://k6.io/docs/javascript-api/k6-browser/), you need to pass the `K6_BROWSER_ENABLED=true` environment variable:

```bash
K6_BROWSER_ENABLED=true k6 run --iterations 1 --vus 1 browser.js
```

If the test uses an extension, you need to build it first via xk6:

```bash
xk6 build --with xk6-internal=.
```

For example, if you want to build the [xk6-disruptor](https://github.com/grafana/xk6-disruptor) for fault injection testing, you can use the following command:

```bash
xk6 build --with github.com/grafana/xk6-disruptor --output disruptork6
```

This will create a binary called `disruptork6` in your directory. 

If you get an error building the binary, go back to your parent directory and build the binary again. Afterwards, you can run the test from your parent directory or move the binary to the QuickPizza folder.

To run this binary anywhere in your folder, you can copy it your `/usr/local/bin` directory.

### Running a Prometheus instance

If you want to stream the metrics to a Prometheus instance, you need, well, a Prometheus instance. You can use the following command to run a local one:

```bash
docker run -p 9090:9090 prom/prometheus --config.file=/etc/prometheus/prometheus.yml \
             --storage.tsdb.path=/prometheus \
             --web.console.libraries=/usr/share/prometheus/console_libraries \
             --web.console.templates=/usr/share/prometheus/consoles \
             --web.enable-remote-write-receiver
```

## Deploy application to Kubernetes

When working with the xk6-disruptor test, you need to deploy the pizza application to Kubernetes.

To start, make sure you stop the Docker container first for `QuickPizza`.

Then, start minikube by running the command:

```bash
minikube start
```

To deploy the application, run: 

```bash
kubectl apply -f pizza-info.yaml --namespace=pizza-ns
```

The IP of the service should be `pending`:

```bash
kubectl get all -n pizza-ns

NAME                 TYPE           CLUSTER-IP       EXTERNAL-IP   PORT(S)          AGE
service/pizza-info   LoadBalancer   10.108.142.101   <pending>     3333:30076/TCP   13s
```

The next step is to [assign the external IP of the cluster](https://k6.io/docs/javascript-api/xk6-disruptor/get-started/expose-your-application/). Using `minikube`, open another terminal window and run:

```bash
minikube tunnel
```

The external IP should be assigned:

```bash
kubectl get all -n pizza-ns

NAME                 TYPE           CLUSTER-IP       EXTERNAL-IP   PORT(S)          AGE
service/pizza-info   LoadBalancer   10.108.142.101   127.0.0.1     3333:30076/TCP   39s
```

Now you can go to [localhost:3333](http://localhost:3333) and get some pizza recommendations!

To run a basic xk6-disruptor test, run the following command:

```bash
cd k6/tests/disruptor
disruptork6 run 01.basic.js
```

This assumes you have moved `disruptork6` binary to `/usr/local/bin`.

To run an example hybrid test of browser and xk6-disruptor, run the following command:

```bash
cd k6/tests/hybrid
K6_BROWSER_ENABLED=true disruptork6 run 01.browser-with-disruptor.js
```

## Deploy to Fly.io

[Authenticate using the fly CLI](https://fly.io/docs/speedrun/). Then, run the CLI to deploy the application and set up the internal port `3333` that the server listens to.

```bash
fly launch --internal-port 3333 --now
```