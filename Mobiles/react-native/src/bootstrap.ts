import {
  InternalLoggerLevel,
  SamplingRate,
  initializeFaroAsync,
  type ReactNativeConfig,
} from './core/o11y/faroSdk';

import { extractTokenFromCollectorUrl } from './core/utils/faroUtils';
import { getFaroCollectorUrl } from './core/config/configService';

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
  try {
    // Skip if already initialized (e.g. when app is resumed from background)
    if (faroInitialized) {
      ORIGINAL_CONSOLE.info('[Faro] Already initialized, skipping');
      return;
    }

    const collectorUrl = getFaroCollectorUrl();
    const apiKey = extractTokenFromCollectorUrl(collectorUrl);
    
    ORIGINAL_CONSOLE.info('[Faro] Starting initialization');
    ORIGINAL_CONSOLE.info('[Faro] Collector URL:', collectorUrl);
    ORIGINAL_CONSOLE.info('[Faro] API Key extracted:', apiKey ? '✓ (present)' : '✗ (missing)');

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
       * Using volatile (in-memory) sessions to avoid AsyncStorage delays.
       */
      sessionTracking: {
        enabled: true,
        persistent: false, // Use in-memory sessions (faster, no AsyncStorage)
        sampling: new SamplingRate(1), // 100% sampling
      },

      /** Repeated identical `faro.tracing.fetch` payloads are otherwise merged by faro-core dedupe. */
      dedupe: false,

      cpuUsageVitals: true,
      memoryUsageVitals: true,
      refreshRateVitals: false,
      anrTracking: true,
      fetchVitalsInterval: __DEV__ ? 5000 : 30000,

      enableErrorReporting: true,
      enableCrashReporting: true,
      enableConsoleCapture: true,

      internalLoggerLevel: __DEV__
        ? InternalLoggerLevel.ERROR // Reduce log noise - only errors
        : InternalLoggerLevel.ERROR,

      enableTransports: {
        offline: false, // Disable offline storage to avoid AsyncStorage delays
        console: false, // Disable console transport - it logs every item which is slow
      },

      enableTracing: false,
    };

    ORIGINAL_CONSOLE.info('[Faro] Config built, calling initializeFaroAsync...');
    ORIGINAL_CONSOLE.info('[Faro] Session tracking config:', JSON.stringify({
      enabled: config.sessionTracking?.enabled,
      persistent: config.sessionTracking?.persistent,
      hasSampling: !!config.sessionTracking?.sampling,
    }));
    const faro = await initializeFaroAsync(config);
    ORIGINAL_CONSOLE.info('[Faro] initializeFaroAsync returned, faro.api exists?', !!faro?.api);
    
    // Wait a bit for session to initialize
    await new Promise(resolve => setTimeout(resolve, 100));
    
    // Check session state
    const sessionMeta = faro?.metas?.value?.session;
    ORIGINAL_CONSOLE.info('[Faro] Session meta:', sessionMeta ? `id=${sessionMeta.id}, attributes=${JSON.stringify(sessionMeta.attributes || {})}` : 'NOT AVAILABLE');
    
    if (!sessionMeta?.id) {
      ORIGINAL_CONSOLE.error('[Faro] SESSION NOT CREATED! This will cause 400 errors from collector.');
    }

    // When Faro is already registered, initializeFaro logs an error and returns undefined
    // (it does not throw). Mark as initialized to avoid retry loops on app resume.
    if (!faro?.api) {
      ORIGINAL_CONSOLE.warn('[Faro] Faro API not available - already registered or initialization failed');
      faroInitialized = true;
      return;
    }
    
    ORIGINAL_CONSOLE.info('[Faro] Sessions initialized, pushing test event...');

    // At this point, all instrumentations including SessionInstrumentation are fully initialized
    // and the session is available for error reporting
    faro.api.pushEvent('faro_initialized', {
      timestamp: new Date().toISOString(),
    });
    ORIGINAL_CONSOLE.info('[Faro] Test event pushed, initialization complete');
    
    // Check transports
    const transports = faro?.transports?.transports || [];
    ORIGINAL_CONSOLE.info('[Faro] Active transports:', transports.map((t: any) => t.name).join(', '));
    
    // Wait a bit and check session again
    setTimeout(() => {
      const sessionMeta2 = faro?.metas?.value?.session;
      ORIGINAL_CONSOLE.info('[Faro] Session meta (after 2s):', sessionMeta2 ? `id=${sessionMeta2.id}` : 'STILL NOT AVAILABLE');
    }, 2000);

    faroInitialized = true;
  } catch (error) {
    ORIGINAL_CONSOLE.error('[Faro] Initialization failed:', error instanceof Error ? error.message : String(error));
    if (error instanceof Error && error.stack) {
      ORIGINAL_CONSOLE.error('[Faro] Stack trace:', error.stack);
    }
  }
}
