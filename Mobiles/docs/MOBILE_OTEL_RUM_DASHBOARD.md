# Mobile OTel RUM Dashboard

This guide explains how to import and configure the reusable Mobile OTel RUM
dashboard for native Android and iOS apps that send OpenTelemetry logs and
traces to Grafana Cloud.

The dashboard is a lightweight RUM-style view for mobile telemetry while
Frontend Observability does not ingest native OTLP mobile data directly. It
queries the stack's Loki and Tempo data sources, which are populated through
Grafana Cloud OTLP ingest.

## Dashboard Artifact

The dashboard JSON lives at:

```text
Mobiles/dashboards/mobile-otel-rum-dashboard.json
```

It uses Grafana's dashboard resource format and a tabbed layout, so it requires
Grafana 13 or later.

## Requirements

- Grafana 13 or later.
- A Grafana Cloud stack with OTLP ingest enabled for logs and traces.
- Native Android or iOS telemetry collected with the [OpenTelemetry Android SDK](https://github.com/open-telemetry/opentelemetry-android) or [OpenTelemetry Swift](https://github.com/open-telemetry/opentelemetry-swift), shaped like the QuickPizza demo apps.
- A Loki data source named `grafanacloud-logs`.
- A Tempo data source named `grafanacloud-traces`.

Grafana Cloud stacks commonly use these data source names. If your stack or OSS
Grafana instance uses different names, update the data source references after
import.

## Import the Dashboard

1. Open your Grafana stack.
2. Go to **Dashboards**.
3. Select **New** and then **Import dashboard**.
4. Upload or paste `Mobiles/dashboards/mobile-otel-rum-dashboard.json`.
5. Save the dashboard.

If you manage Grafana resources as code, you can also push the JSON resource
with `gcx` or Git Sync.

## Configure Mobile Service Names

The dashboard uses a custom multi-value variable named `service_name`, labeled
**Mobile service names**.

Edit that variable and replace the demo values with the OpenTelemetry
`service.name` values for your apps. For example:

```text
my-app-android, my-app-ios
```

The default values (`quickpizza-android`, `quickpizza-ios`) are from the
QuickPizza demo apps. Replace them after import unless you are viewing the demo
stack.

The list is intentionally manual. Grafana Cloud stacks often contain backend
services in the same Loki and Tempo data sources, so automatic service
discovery would include unrelated services.

You can also type a service name directly into the dropdown because custom
values are enabled.

## Expected Telemetry Shape

The dashboard expects the same broad telemetry contract used by the native
QuickPizza demo apps.

Every signal should include these OpenTelemetry resource attributes:

```text
service.name
service.namespace
service.version
deployment.environment
```

Session-aware views expect session attributes to be present. In Grafana Cloud
Loki queries, `session.id` is available as `session_id`.

Android signals from `opentelemetry-android` include events such as:

- `screen.view`
- `app.jank`
- `session.start`
- `rum.sdk.init.*`
- `exception`
- `device.crash`
- `device.anr`

iOS signals from OpenTelemetry Swift plus the QuickPizza app instrumentation
include:

- `app.screen.view`
- `session.start`
- `exception`
- MetricKit crash, hang, CPU, disk-write, and app-launch diagnostics
- URLSession spans
- manual business spans such as `pizza.get_recommendation`, `auth.login`, and
  `pizza.rate`

For platform-specific setup details, see:

- [Android Native Setup Guide](./ANDROID_NATIVE_SETUP.md)
- [iOS OpenTelemetry Instrumentation Guide](./IOS_OBSERVABILITY_OTEL_GUIDE.md)

## Troubleshooting

If the dashboard is empty:

- Confirm that the selected time range contains recent telemetry.
- Confirm that **Mobile service names** matches your app's `service.name`.
- Confirm that the app is exporting OTLP over HTTP to the correct Grafana Cloud
  endpoint.
- Confirm that the OTLP credentials allow `logs:write` and `traces:write`.
- Confirm that the dashboard points at the correct Loki and Tempo data source
  names.

For Android, use the Debug tab to emit a debug log, handled exception, ANR, or
crash event. For iOS, use the Debug tab to emit logs and handled exceptions.
MetricKit crash and hang diagnostics are delayed by Apple and may arrive later.
