## Deploy QuickPizza Docker image

The [Dockerfile](./Dockerfile) contains the setup for running QuickPizza without collecting data with Grafana Alloy.

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