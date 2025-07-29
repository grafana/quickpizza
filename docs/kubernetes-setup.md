
# Deploy QuickPizza to Kubernetes

This section explains how to deploy QuickPizza to a local Kubernetes cluster using [minikube](https://minikube.sigs.k8s.io/docs/start/), which you can run on your own machine if you use Linux, MacOS, or Windows.

Minikube is available in the software distribution channel for your OS of choice: `apt` or similar for Linux, `brew` for macOS, and `winget` or chocolatey for Windows. For more details on how to install Minikube, you can check the "Installation" section on the [Minikube documentation](https://minikube.sigs.k8s.io/docs/start/).

We recommend that you use the latest version of Kubernetes available. We have verified the following instructions for kubernetes 1.19 and above.

After installing minikube, you can start a local cluster with the following command:

```bash
minikube start
```

To deploy the application, run: 

```bash
cd kubernetes/basic/
kubectl apply -k .
```

The `kustomization.yaml` file contains some commented lines that, if enabled, will configure tracing for the QuickPizza app. Feel free to uncomment those lines and input your OTLP credentials if you want this functionality.

When deployed in Kubernetes, it deploys a number of different pods, each one being a microservice for the application:

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

A service of particular interest is `quickpizza-frontend`, of type `LoadBalancer`. This is the service we need to access in our browser to reach the application. You should see that the external IP for this service is currently `<pending>`. In order to make it reachable from outside the cluster, we need to expose it. To do this with minikube, open another terminal window and run:

```bash
minikube tunnel
```

The command will stay running in the foreground, forwarding traffic to the cluster.

The external IP should now be assigned:

```bash
kubectl get services

NAME                  TYPE           CLUSTER-IP       EXTERNAL-IP     PORT(S)          AGE
quickpizza-frontend   LoadBalancer   10.99.177.165    127.0.0.1   3333:30333/TCP   3m9s
# Other services elided for brevity
```

You should now be able to access the application on port `3333` in the IP address noted below in your browser, which in our example was `127.0.0.1`. 


## Enable telemetry in Kubernetes

To collect telemetry data, use one of the following setups:

- `kubernetes/cloud-telemetry`: For sending telemetry to a remote cloud service.
- `kubernetes/local-telemetry`: For collecting telemetry locally.

Before deployment:

- Set the required credentials in a `.env` file located in the respective folder.
- Configure any additional settings as needed.
- Deploy the Kubernetes application using `minikube` and `kubectl`, following the same steps described in the earlier setup instructions.

![Screenshot of a trace visualized in Grafana Tempo](https://github.com/grafana/QuickPizza/assets/969721/4088f92b-c98c-4631-9681-c2ce8a49d721)
