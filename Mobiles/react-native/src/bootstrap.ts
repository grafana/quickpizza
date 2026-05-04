import { InternalLoggerLevel, LogLevel, SamplingRate, initializeFaro, type ReactNativeConfig } from './core/o11y/faroSdk';

import { extractTokenFromCollectorUrl } from './core/utils/faroUtils';
import { getFaroCollectorUrl, getQuickPizzaTracePropagationUrlPatterns } from './core/config/configService';

const APP_VERSION = '1.0.0';
const APP_ENV = __DEV__ ? 'development' : 'production';

let faroInitialized = false;

// Capture the original console BEFORE any patching happens (RN DevTools, LogBox, etc.)
// This is critical to prevent infinite loops in ConsoleInstrumentation
const ORIGINAL_CONSOLE = {
  log: console.log.bind(console),
  info: console.info.bind(console),
  warn: console.warn.bind(console),
  error: console.error.bind(console),
  debug: console.debug.bind(console),
  trace: console.trace.bind(console),
};

export async function initFaro(): Promise<void> {
  // Skip if already initialized (e.g. when app is resumed from background)
  if (faroInitialized) {
    ORIGINAL_CONSOLE.info('[Faro] Already initialized, skipping');
    return;
  }

  const collectorUrl = getFaroCollectorUrl();
  const apiKey = extractTokenFromCollectorUrl(collectorUrl);

  const config: ReactNativeConfig = {
    app: {
      name: 'QuickPizza_ReactNative',
      version: APP_VERSION,
      environment: APP_ENV,
    },
    url: collectorUrl,
    apiKey: apiKey || undefined,
    
    // Provide the original unpatched console to prevent infinite loops
    unpatchedConsole: ORIGINAL_CONSOLE as Console,

    /**
     * Session tracking with 100% sampling.
     * Volatile (in-memory) sessions. `initializeFaro` loads device/session attributes first, then inits core Faro.
     */
    sessionTracking: {
      enabled: true,
      persistent: false, // Use in-memory sessions (faster, no storage)
      sampling: new SamplingRate(1), // 100% sampling
    },

    /** Repeated identical `faro.tracing.fetch` payloads are otherwise merged by faro-core dedupe. */
    dedupe: false,

    cpuUsageVitals: true,
    memoryUsageVitals: true,
    refreshRateVitals: true,
    anrTracking: true,
    fetchVitalsInterval: __DEV__ ? 5000 : 30000,

    enableErrorReporting: true,
    enableCrashReporting: true,
    enableConsoleCapture: true,
    consoleCaptureOptions: {
      disabledLevels: [LogLevel.DEBUG, LogLevel.TRACE, LogLevel.LOG, LogLevel.ERROR],
    },

    internalLoggerLevel: __DEV__
      ? InternalLoggerLevel.VERBOSE
      : InternalLoggerLevel.ERROR,

    enableTransports: {
      offline: false, // Disable offline storage to avoid storage delays
      console: false, // Disable console transport - it logs every item which is slow
    },

    enableTracing: true,
    // Propagate trace context to QuickPizza. For one trace in Tempo, run the backend with
    // QUICKPIZZA_TRUST_CLIENT_TRACEID=true (already set in compose.grafana-*.yaml quickpizza service).
    tracingOptions: {
      instrumentationOptions: {
        propagateTraceHeaderCorsUrls: getQuickPizzaTracePropagationUrlPatterns(),
      },
    },
  };
  const faro = await initializeFaro(config);

  // When Faro is already registered, initializeFaro logs an error and returns undefined
  // (it does not throw). Mark as initialized to avoid retry loops on app resume.
  if (!faro?.api) {
    faroInitialized = true;
    return;
  }

  // At this point, all instrumentations including SessionInstrumentation are fully initialized
  // and the session is available for error reporting
  faro.api.pushEvent('faro_initialized', {
    timestamp: new Date().toISOString(),
  });
  

  faroInitialized = true;
}
