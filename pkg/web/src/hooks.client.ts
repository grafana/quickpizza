import {getWebInstrumentations, initializeFaro} from '@grafana/faro-web-sdk';
import {TracingInstrumentation} from '@grafana/faro-web-tracing';
import {PUBLIC_BACKEND_ENDPOINT} from '$env/static/public'

function setupFaro() {
    fetch(`${PUBLIC_BACKEND_ENDPOINT}api/config`).
    then(data => data.json()).
    then(config => {
        const url = config.faro_url;
        if (!url) {
            console.warn("Grafana faro is not configured.")
            return
        }

        console.log(`Initializing Grafana Faro to ${url}`)
        initializeFaro({
            url,
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

    }).
    catch(e => {
        console.error("Cannot read config from backend")
        console.error(e.message)
    });
}

setupFaro();
