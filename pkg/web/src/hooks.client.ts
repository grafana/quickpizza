import { ReplayInstrumentation } from '@grafana/faro-instrumentation-replay';
import { getWebInstrumentations, initializeFaro } from '@grafana/faro-web-sdk';
import { TracingInstrumentation } from '@grafana/faro-web-tracing';
import { PUBLIC_BACKEND_ENDPOINT } from '$env/static/public';

function setupFaro() {
	fetch(`${PUBLIC_BACKEND_ENDPOINT}/api/config`)
		.then((data) => data.json())
		.then((config) => {
			const url = config.faro_url;
			const faroAppName = config.faro_app_name || 'QuickPizza';
			const faroAppNamespace = config.faro_app_namespace || 'quickpizza';
			const faroAppVersion = config.faro_app_version || '1.0.0';
			const faroAppEnvironment = config.faro_app_environment || 'production';
			const faroInstrumentationEnableReplay =
				config.faro_instrumentation_enable_replay === 'true';

			if (!url) {
				console.warn('Grafana Faro is not configured.');
			}

			const instrumentations = [
				// Mandatory, overwriting the instrumentations array would cause the default instrumentations to be omitted
				...getWebInstrumentations(),

				// Initialization of the tracing package.
				// This packages is optional because it increases the bundle size noticeably. Only add it if you want tracing data.
				new TracingInstrumentation(),
			];

			if (faroInstrumentationEnableReplay) {
				instrumentations.push(
					new ReplayInstrumentation({
						maskAllInputs: true,
						collectFonts: true,
						inlineImages: true,
						inlineStylesheet: true,
					}),
				);
			}

			console.log(`Initializing Grafana Faro to '${url}'`);
			initializeFaro({
				url,
				app: {
					name: faroAppName,
					namespace: faroAppNamespace,
					version: faroAppVersion,
					environment: faroAppEnvironment,
				},
				instrumentations,
			});
		})
		.catch((e) => {
			console.error('Cannot read config from backend');
			console.error(e.message);
		});
}

setupFaro();
