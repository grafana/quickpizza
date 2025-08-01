
### Running xk6-disruptor tests

If you want to run a test that uses [xk6-disruptor](https://grafana.com/docs/k6/latest/testing-guides/injecting-faults-with-xk6-disruptor/first-steps/), or you will need to deploy QuickPizza to Kubernetes. 


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

