import { getWebInstrumentations, initializeFaro } from '@grafana/faro-web-sdk';
import { TracingInstrumentation } from '@grafana/faro-web-tracing';
import { PUBLIC_FARO_WEBSDK_URL } from '$env/static/public'

initializeFaro({
  url: PUBLIC_FARO_WEBSDK_URL,
  app: {
    name: 'QuickPizza',
    version: '1.0.0',
    environment: 'production'
  },
  instrumentations: [
    // Mandatory, overwriting the instrumentations array would cause the default instrumentations to be omitted
    ...getWebInstrumentations(),

    // Initialization of the tracing package.
    // This packages is optional because it increases the bundle size noticeably. Only add it if you want tracing data.
    new TracingInstrumentation(),
  ],
});