# QuickPizza

![Screenshot from 2023-03-18 15-29-05](https://user-images.githubusercontent.com/8228060/226112255-fe2d4cdc-193e-4c23-8a36-3d8f60baaf03.png)

## What is QuickPizza? 🍕🍕🍕

`QuickPizza` is a web application, used for demonstrations and workshops, that generates new and exciting pizza combinations! 

The app is built using [SvelteKit](https://kit.svelte.dev/) for the frontend and [Go](https://go.dev/) for the backend.

The tests written for `QuickPizza` demonstrates the basic and advanced functionalities of k6, ranging from a basic load test to using different modules and extensions.

## Requirements

- [Docker](https://docs.docker.com/get-docker/)
- [Grafana k6](https://k6.io/docs/get-started/installation/) (v.0.43.1 or higher)

If you are running the xk6-disruptor test, Kubernetes needs to be setup and `minikube` to be downloaded. 

- [Minikube](https://minikube.sigs.k8s.io/docs/start/)

## Run locally with Docker

To run the app locally with Docker, run the command:

```bash
docker run --rm -it -p 3333:3333  ghcr.io/grafana/quickpizza-local:latest
```

That's it!

Now you can go to [localhost:3333](http://localhost:3333) and get some pizza recommendations!

## Using k6 to test it

All tests live in the `k6` folder. Within this folder, you will find the following folders:

- [foundations](k6/foundations/) - covers the basic functionalities of k6.
- [browser](k6/browser/) - covers a more deep-dive look on how to use the k6 browser module for browser and web performance testing.
- [disruptor](k6/disruptor/) - covers a more deep-dive look on how to use xk6-disruptor for failure injection testing.
- [advanced](k6/advanced) - covers tests that are more advanced such as hybrid tests, tracing, etc.

To run tests on the `foundations` folder, you can use the following commands:

```bash
cd k6/foundations
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

If the test uses an extension, you need to build it first via xk6. To build the extension using Docker, you can run the following command:

```bash
cd k6/foundations/extension

docker run --rm -e GOOS=darwin -u "$(id -u):$(id -g)" -v "${PWD}:/xk6" \
  grafana/xk6 build  \
  --with xk6-internal=.
```

Note that the `GOOS` variable is for Mac. Please refer to [Build a k6 binary using Docker](https://k6.io/docs/extensions/guides/build-a-k6-binary-using-docker/) for more information.

To run the test that uses an extension, you can run the following command:

```bash
K6_BROWSER_ENABLED=true ./extension/k6 run 11.extension.js
```

## Running a Prometheus instance

If you want to stream the metrics to a Prometheus instance, you need, well, a Prometheus instance. You can use the following command to run a local one:

```bash
docker run -p 9090:9090 prom/prometheus --config.file=/etc/prometheus/prometheus.yml \
             --storage.tsdb.path=/prometheus \
             --web.console.libraries=/usr/share/prometheus/console_libraries \
             --web.console.templates=/usr/share/prometheus/consoles \
             --web.enable-remote-write-receiver
```

## Enable tracing in Docker

A common pattern to set up tracing is to configure your application to forward traces to an agent, which in turn forwards them to your tracing backend, such as a Grafana Stack. QuickPizza can be configured to do this by setting `QUICKPIZZA_OTLP_ENDPOINT` to the URL of said agent (in this case, we will use the [grafana/agent](https://github.com/grafana/agent)), which in turn can be configured through environment variables.

If you have a QuickPizza container running from previous steps, you can stop it now, as we will need to launch it again with tracing enabled. To do so, you can run the following commands:

```shell
# Configure URL, user, and API key for your tracing backend.
# If you use Grafana Cloud, you can get your credentials following these steps: https://grafana.com/docs/agent/latest/flow/getting-started/opentelemetry-to-lgtm-stack/#grafana-tempo
 export TRACES_ENDPOINT=your-tracing-endpoint.grafana.local:443
 export TRACES_USER=12345
 export TRACES_API_KEY=your-api-key
# Create a docker network so quickpizza and grafana-agent containers can talk to each other:
docker network create quickpizza
# Run the grafana agent. The provided config is not kubernetes-specific and works in Docker as well.
docker run --name grafana-agent --rm -i -v ./kubernetes/grafana-agent/config/grafana-agent.river:/grafana-agent.river --network quickpizza -e TRACES_ENDPOINT -e TRACES_USER -e TRACES_API_KEY -e AGENT_MODE=flow grafana/agent run /grafana-agent.river
# On a different terminal, run the QuickPizza container on the same network with tracing enabled:
docker run --rm -i -p 3333:3333 -e QUICKPIZZA_OTLP_ENDPOINT=http://grafana-agent:4318 -e QUICKPIZZA_TRUST_CLIENT_TRACEID=1 --network quickpizza ghcr.io/grafana/quickpizza-local:latest
```

The `QUICKPIZZA_TRUST_CLIENT_TRACEID` environment variable instructs QuickPizza to trust client-provided Trace IDs, so all client-generated spans (if any) will show up in the trace.

## Deploy application to Kubernetes

If you want to run a test that uses xk6-disruptor, or want to experiment with distributed tracing, you will need to deploy QuickPizza to Kubernetes. This section explains how to deploy QuickPizza to a local Kubernetes cluster using minikube, which you can run on your own machine if you use Linux, MacOS, or Windows.

Minikube is available in the software distribution channel for your OS of choice: `apt` or similar for Linux, `brew` for macOS, and `winget` or chocolatey for Windows. For more details on how to install Minikube, you can check the "Installation" section on the [Minikube documentation](https://minikube.sigs.k8s.io/docs/start/).

We recommend that you use the latest version of Kubernetes available. We have verified the following instructions for kubernetes 1.19 and above. Keep in mind that `xk6-disruptor` requires Kubernetes 1.25 or above.

After installing minikube, you can start a local cluster with the following command:

```bash
minikube start
```

To deploy the application, run: 

```bash
kubectl apply -k kubernetes/
```

The `kubernetes/kustomization.yaml` file contains some commented lines that, if enabled, will configure tracing for the quickpizza app. Feel free to uncomment those lines and input your OTLP credentials if you want this functionality.

When deployed in Kubernetes, the QuickPizza manifests locates in `./kubernetes` will deploy a number of different pods, each one being a microservice for the application:

```
kubectl get pods

NAME                                  READY   STATUS    RESTARTS   AGE
quickpizza-catalog-749d46c785-4q6s5   1/1     Running   0          7s
quickpizza-copy-7f879947c5-rslhg      1/1     Running   0          7s
quickpizza-frontend-bf447c76-9nb8f    1/1     Running   0          7s
quickpizza-recs-644d498964-6l48p      1/1     Running   0          7s
quickpizza-ws-7d444d9cd6-mkkmd        1/1     Running   0          7s
```

You should also see a bunch of services associated with these pods:

```
kubectl get services

NAME                  TYPE           CLUSTER-IP       EXTERNAL-IP   PORT(S)          AGE
kubernetes            ClusterIP      10.96.0.1        <none>        443/TCP          1s
quickpizza-catalog    ClusterIP      10.104.201.242   <none>        3333/TCP         6s
quickpizza-copy       ClusterIP      10.97.255.59     <none>        3333/TCP         6s
quickpizza-frontend   LoadBalancer   10.99.177.165    <pending>     3333:30333/TCP   6s
quickpizza-recs       ClusterIP      10.103.37.197    <none>        3333/TCP         6s
quickpizza-ws         ClusterIP      10.106.51.76     <none>        3333/TCP         6s
```

A service of particular interest is `quickpizza-frontend`, of type `LoadBalancer`. This is the service we need to access in our browser to reach the application. You should see that the external IP for this service is currently `<pending>`. In order to make it reachable from outside the cluster, we need to [expose it](https://k6.io/docs/javascript-api/xk6-disruptor/get-started/expose-your-application/). To do this with minikube, open another terminal window and run:

```bash
minikube tunnel
```

The command will stay running in the foreground, forwarding traffic to the cluster.

The external IP should now be assigned:

```bash
kubectl get services

NAME                  TYPE           CLUSTER-IP       EXTERNAL-IP     PORT(S)          AGE
quickpizza-frontend   LoadBalancer   10.99.177.165    10.99.177.165   3333:30333/TCP   3m9s
# Other services elided for brevity
```

You should now be able to access the application on port `3333` in the IP address noted below in your browser, which in our example was `10.99.177.165`. Depending on the OS you're using, it might be `127.0.0.1`, which is also fine.

We can save this IP on an environment variable for using it later on tests:

```shell
export BASE_URL="http://$(kubectl get svc quickpizza-frontend -o jsonpath='{.status.loadBalancer.ingress[0].ip}'):3333"
echo $BASE_URL
# You should see something like:
# http://10.99.177.165:3333
```

### Enable tracing in Kubernetes

Distributed tracing support can be enabled when deploying in Kubernetes by editing the `kubernetes/kustomization.yaml` file and following the instructions in the comments present on that file. You will need a backend capable of ingesting OTLP traces, such as a Grafana Cloud Stack, or a Tempo deployment.

After making the changes `kubernetes/kustomization.yaml`, you may need to restart the QuickPizza pods for them to pick up the new configuration:

```shell
kubectl delete pods -l app.k8s.io/name=quickpizza
```

![Screenshot of a trace visualized in Grafana Tempo](https://github.com/grafana/quickpizza/assets/969721/4088f92b-c98c-4631-9681-c2ce8a49d721)

### Running xk6-disruptor tests

To build the [xk6-disruptor](https://github.com/grafana/xk6-disruptor) extension for fault injection testing, you can use the following command:

```bash
cd k6/disruptor

docker run --rm -e GOOS=darwin -u "$(id -u):$(id -g)" -v "${PWD}:/xk6" \
  grafana/xk6 build  \
  --with github.com/grafana/xk6-disruptor
```

To run a basic xk6-disruptor test, run the following command on the `k6/disruptor` folder:

```bash
./k6 run 01.basic.js
```

To run an example hybrid test of browser and xk6-disruptor, run the following command:

```bash
K6_BROWSER_ENABLED=true ./k6 run ../advanced/01.browser-with-disruptor.js
```

## Deploy to Fly.io

[Authenticate using the fly CLI](https://fly.io/docs/speedrun/). Then, run the CLI to deploy the application and set up the internal port `3333` that the server listens to.

```bash
fly launch --internal-port 3333 --now
```
