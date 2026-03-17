import { InternalLoggerLevel } from '@grafana/faro-core';

import {
  SamplingFunction,
  initializeFaro,
  type ReactNativeConfig,
} from '@grafana/faro-react-native';

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

      sessionTracking: {
        sampling: new SamplingFunction((context) =>
          context.meta.app?.environment === 'production' ? 0.1 : 1,
        ),
      },

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

      enableTracing: true,
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
