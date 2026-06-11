# GitHub Actions Workflows

## Real CI

| Workflow | Purpose |
|----------|---------|
| `ci.yaml` | **Authoritative CI.** Builds the binary from source, runs linters, and runs the full k6 test suite (foundations, internal, browser). Runs on every push. |
| `docker_publish.yaml` | Builds and pushes multi-arch Docker images to GHCR on release. |

## Demo workflows (`example_*`)

These workflows demonstrate how to use the [grafana/setup-k6-action](https://github.com/grafana/setup-k6-action) and [grafana/run-k6-action](https://github.com/grafana/run-k6-action) GitHub Actions. They run against a published QuickPizza Docker image and are not part of the real CI pipeline.

| Workflow | Demonstrates |
|----------|-------------|
| `example_tests.yaml` | Basic test run and running all foundation + internal tests |
| `example_browser_tests.yaml` | Browser test run and running all browser tests |
| `example_cli_flags_test.yaml` | Passing CLI flags to k6 (`--vus`, `--duration`) |
| `example_env_var.yaml` | Passing environment variables to k6 |
| `example_specific_k6_version.yaml` | Pinning a specific k6 version |
| `example_verify_scripts.yaml` | Verifying scripts without executing them |
