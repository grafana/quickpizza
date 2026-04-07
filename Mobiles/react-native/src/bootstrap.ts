import {
  InternalLoggerLevel,
  SamplingRate,
  initializeFaro,
  type ReactNativeConfig,
} from './core/o11y/faroSdk';

import { extractTokenFromCollectorUrl } from './core/utils/faroUtils';
import { getFaroCollectorUrl } from './core/config/configService';

const APP_VERSION = '1.0.0';
const APP_ENV = __DEV__ ? 'development' : 'production';

let faroInitialized = false;

export function initFaro(): void {
  try {
    // Skip if already initialized (e.g. when app is resumed from background)
    if (faroInitialized) {
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

      /**
       * Session sampling must mark the session as sampled or SessionInstrumentation's beforeSend
       * hook drops every outbound item (`packages/react-native/src/instrumentations/session/index.ts`).
       * For this demo, always sample so `faro.tracing.fetch` (and other signals) reach Grafana.
       */
      sessionTracking: {
        sampling: new SamplingRate(1),
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

      internalLoggerLevel: __DEV__
        ? InternalLoggerLevel.VERBOSE
        : InternalLoggerLevel.ERROR,

      enableTransports: {
        offline: true,
        console: __DEV__,
      },

      enableTracing: false,
    };

    const faro = initializeFaro(config);

    // When Faro is already registered, initializeFaro logs an error and returns undefined
    // (it does not throw). Mark as initialized to avoid retry loops on app resume.
    if (!faro?.api) {
      faroInitialized = true;
      return;
    }

    faro.api.pushEvent('faro_initialized', {
      timestamp: new Date().toISOString(),
    });

    faroInitialized = true;
  } catch (error) {
    if (__DEV__) {
      console.warn('[Faro] Initialization failed:', error);
    }
  }
}
