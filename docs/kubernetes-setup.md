
## Deploy QuickPizza to Kubernetes

If you want to run a test that uses [xk6-disruptor](https://grafana.com/docs/k6/latest/testing-guides/injecting-faults-with-xk6-disruptor/first-steps/), or want to experiment with distributed tracing, you will need to deploy QuickPizza to Kubernetes. 


This section explains how to deploy QuickPizza to a local Kubernetes cluster using [minikube](https://minikube.sigs.k8s.io/docs/start/), which you can run on your own machine if you use Linux, MacOS, or Windows.

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

The `kubernetes/kustomization.yaml` file contains some commented lines that, if enabled, will configure tracing for the QuickPizza app. Feel free to uncomment those lines and input your OTLP credentials if you want this functionality.

When deployed in Kubernetes, the QuickPizza manifests locates in `./kubernetes` will deploy a number of different pods, each one being a microservice for the application:

```
kubectl get pods

NAME                                  READY   STATUS    RESTARTS   AGE
QuickPizza-catalog-749d46c785-4q6s5   1/1     Running   0          7s
QuickPizza-copy-7f879947c5-rslhg      1/1     Running   0          7s
QuickPizza-frontend-bf447c76-9nb8f    1/1     Running   0          7s
QuickPizza-recs-644d498964-6l48p      1/1     Running   0          7s
QuickPizza-ws-7d444d9cd6-mkkmd        1/1     Running   0          7s
```

You should also see a bunch of services associated with these pods:

```
kubectl get services

NAME                  TYPE           CLUSTER-IP       EXTERNAL-IP   PORT(S)          AGE
kubernetes            ClusterIP      10.96.0.1        <none>        443/TCP          1s
QuickPizza-catalog    ClusterIP      10.104.201.242   <none>        3333/TCP         6s
QuickPizza-copy       ClusterIP      10.97.255.59     <none>        3333/TCP         6s
QuickPizza-frontend   LoadBalancer   10.99.177.165    <pending>     3333:30333/TCP   6s
QuickPizza-recs       ClusterIP      10.103.37.197    <none>        3333/TCP         6s
QuickPizza-ws         ClusterIP      10.106.51.76     <none>        3333/TCP         6s
```

A service of particular interest is `QuickPizza-frontend`, of type `LoadBalancer`. This is the service we need to access in our browser to reach the application. You should see that the external IP for this service is currently `<pending>`. In order to make it reachable from outside the cluster, we need to [expose it](https://grafana.com/docs/k6/latest/testing-guides/injecting-faults-with-xk6-disruptor/expose-your-application/). To do this with minikube, open another terminal window and run:

```bash
minikube tunnel
```

The command will stay running in the foreground, forwarding traffic to the cluster.

The external IP should now be assigned:

```bash
kubectl get services

NAME                  TYPE           CLUSTER-IP       EXTERNAL-IP     PORT(S)          AGE
QuickPizza-frontend   LoadBalancer   10.99.177.165    10.99.177.165   3333:30333/TCP   3m9s
# Other services elided for brevity
```

You should now be able to access the application on port `3333` in the IP address noted below in your browser, which in our example was `10.99.177.165`. Depending on the OS you're using, it might be `127.0.0.1`, which is also fine.

We can save this IP on an environment variable for using it later on tests:

```shell
export BASE_URL="http://$(kubectl get svc QuickPizza-frontend -o jsonpath='{.status.loadBalancer.ingress[0].ip}'):3333"
echo $BASE_URL
# You should see something like:
# http://10.99.177.165:3333
```

### Enable telemetry in Kubernetes

To collect telemetry information, enable the `grafana-agent/cloud` (or `grafana-agent/local`) resource in `kubernetes/kustomization.yaml` and set the required configuration options.

After making the changes `kubernetes/kustomization.yaml`, you may need to restart the QuickPizza pods for them to pick up the new configuration:

```shell
kubectl delete pods -l app.k8s.io/name=QuickPizza
```

![Screenshot of a trace visualized in Grafana Tempo](https://github.com/grafana/QuickPizza/assets/969721/4088f92b-c98c-4631-9681-c2ce8a49d721)

To ingest logs from Kubernetes, take a look at the [Grafana Cloud Kubernetes Integration](https://grafana.com/solutions/kubernetes) or use the [`loki.source.kubernetes`](https://grafana.com/docs/agent/latest/flow/reference/components/loki.source.kubernetes/)/[`loki.source.file`](https://grafana.com/docs/agent/latest/flow/reference/components/local.file_match/#send-kubernetes-pod-logs-to-loki) agent components.

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
./k6 run ../advanced/01.browser-with-disruptor.js
```