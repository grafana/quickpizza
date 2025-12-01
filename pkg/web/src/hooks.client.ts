import { getWebInstrumentations, initializeFaro } from '@grafana/faro-web-sdk';
import { TracingInstrumentation } from '@grafana/faro-web-tracing';
import * as Sentry from '@sentry/svelte';
import { PUBLIC_BACKEND_ENDPOINT } from '$env/static/public';

function setupFaro(config: Record<string, string>) {
	const url = config.faro_url;
	const faroAppName = config.faro_app_name || 'QuickPizza';
	const faroAppNamespace = config.faro_app_namespace || 'quickpizza';
	const faroAppVersion = config.faro_app_version || '1.0.0';
	const faroAppEnvironment = config.faro_app_environment || 'production';

	if (!url) {
		console.warn('Grafana Faro is not configured.');
		return;
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
		instrumentations: [
			// Mandatory, overwriting the instrumentations array would cause the default instrumentations to be omitted
			...getWebInstrumentations(),

			// Initialization of the tracing package.
			// This packages is optional because it increases the bundle size noticeably. Only add it if you want tracing data.
			new TracingInstrumentation(),
		],
	});
}

function setupSentry(config: Record<string, string>) {
	const dsn = config.sentry_dsn;
	const environment = config.sentry_environment || 'development';
	const release = config.sentry_release || '1.0.0';

	if (!dsn) {
		console.warn('Sentry is not configured (no DSN provided).');
		return;
	}

	console.log('Initializing Sentry for error tracking');
	Sentry.init({
		dsn,
		environment,
		release,
		// Enable performance monitoring
		integrations: [Sentry.browserTracingIntegration()],
		// Set tracesSampleRate to 1.0 to capture 100% of transactions for performance monitoring
		tracesSampleRate: 1.0,
		// Enable debug mode in development
		debug: environment === 'development',
		// Capture all errors on error
		replaysOnErrorSampleRate: 1.0,
		// Capture 10% of sessions for replay
		replaysSessionSampleRate: 0.1,
	});
	console.log('Sentry initialized successfully!');
}

function setupObservability() {
	fetch(`${PUBLIC_BACKEND_ENDPOINT}/api/config`)
		.then((data) => data.json())
		.then((config) => {
			// Initialize Grafana Faro
			setupFaro(config);
			// Initialize Sentry
			setupSentry(config);
		})
		.catch((e) => {
			console.error('Cannot read config from backend');
			console.error(e.message);
		});
}

setupObservability();
