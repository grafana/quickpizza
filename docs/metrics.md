# QuickPizza Prometheus Metrics

This document provides a comprehensive list of Prometheus metrics collected by the QuickPizza application. All metrics are identified by the labels `namespace=quickpizza` or `service_namespace=quickpizza`.

## Go Runtime Metrics

`go_*`

These metrics are automatically collected by the Prometheus Go client library and provide insights into the Go runtime behavior.


## Process Metrics

`process_*`

These metrics provide information about the operating system process running the application.

## PostgreSQL Metrics

`pg_*`

These metrics provide information about the PostgreSQL database connections and operations.

## OpenTelemetry HTTP Metrics

`http_client_*` and `http_server_*`

These metrics are automatically collected by the OpenTelemetry HTTP instrumentation  and provide detailed insights into HTTP request/response patterns. 

Request duration metrics are implemented as **classic histograms** with `_bucket`, `_sum`, and `_count` suffixes.


- `http_server_request_duration`: Duration of HTTP server requests in seconds.
  
- `http_server_request_body_size`: Size of HTTP server request bodies in bytes.
  
- `http_server_response_body_size`: Size of HTTP server response bodies in bytes.

- `http_client_request_duration`: Duration of HTTP client requests in seconds. Measures time spent making outbound HTTP requests. Useful for monitoring external service dependencies.
  
- `http_client_request_body_size`: Size of HTTP client request bodies in bytes.

## Trace-Derived Metrics

`traces_service_graph_*` and `traces_span_metrics_*`

These metrics are generated from distributed traces and are configured in Grafana Alloy or enabled automatically in Grafana Cloud. They provide service-to-service relationship data and span-level metrics from traces.

## QuickPizza Application Metrics

`k6quickpizza_server_*`

These are custom application metrics specific to the QuickPizza application, implemented using the Prometheus Go client library. 

- `k6quickpizza_server_pizza_recommendations_total`: Total number of pizza recommendations served (Counter metric).

- `k6quickpizza_server_number_of_ingredients_per_pizza`: Distribution of ingredients per pizza (Classic Histogram).

- `k6quickpizza_server_number_of_ingredients_per_pizza_alternate`: Distribution of ingredients per pizza (Native Histogram).

- `k6quickpizza_server_pizza_calories_per_slice`: Distribution of calories per pizza slice (Classic Histogram).

- `k6quickpizza_server_pizza_calories_per_slice_alternate`: Distribution of calories per pizza slice (Native Histogram).

- `k6quickpizza_server_http_requests_total`: Total number of HTTP requests received (Counter metric).

- `k6quickpizza_server_http_request_duration_seconds`: Duration of HTTP request processing (Classic Histogram).