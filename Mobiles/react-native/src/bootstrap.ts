import { Platform } from 'react-native';
import {
  TransportItemType,
  type ExceptionEvent,
  type TransportItem,
} from '@grafana/faro-core';
import { InternalLoggerLevel, LogLevel, SamplingRate, initializeFaro, type ReactNativeConfig } from './core/o11y/faroSdk';

import { extractTokenFromCollectorUrl } from './core/utils/faroUtils';
import { getFaroCollectorUrl, getQuickPizzaTracePropagationUrlPatterns } from './core/config/configService';

/**
 * Log Faro `meta.app.bundleId` and exception frame filenames before HTTP send (logcat: `Faro diagnostics`).
 * Off by default. Set `ENABLE_FARO_PAYLOAD_DIAGNOSTICS=true` or `=1` in the environment when Metro bundles
 * the app (same shell as `npx react-native bundle` / `./gradlew installRelease`). Babel inlines this in `babel.config.js`.
 */
const ENABLE_FARO_PAYLOAD_DIAGNOSTICS =
  process.env.ENABLE_FARO_PAYLOAD_DIAGNOSTICS === 'true' ||
  process.env.ENABLE_FARO_PAYLOAD_DIAGNOSTICS === '1';

/** Must match `app.name` and Metro `@grafana/faro-metro-plugin` `appName`. */
const FARO_APP_NAME = 'QuickPizza_ReactNative';

const APP_VERSION = '1.0.0';
const APP_ENV = __DEV__ ? 'development' : 'production';

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

/** Logcat often truncates long lines; split payload fragments for adb. */
function logChunked(tag: string, text: string, chunkSize = 3500): void {
  if (text.length <= chunkSize) {
    ORIGINAL_CONSOLE.info(`${tag} ${text}`);
    return;
  }
  const total = Math.ceil(text.length / chunkSize);
  for (let i = 0; i < total; i++) {
    const part = text.slice(i * chunkSize, (i + 1) * chunkSize);
    ORIGINAL_CONSOLE.info(`${tag} [part ${i + 1}/${total}] ${part}`);
  }
}

function faroPayloadDiagnosticsBeforeSend(item: TransportItem): TransportItem | null {
  if (!ENABLE_FARO_PAYLOAD_DIAGNOSTICS) {
    return item;
  }
  if (item.type !== TransportItemType.EXCEPTION) {
    return item;
  }

  const bundleId = item.meta.app?.bundleId;
  const payload = item.payload as ExceptionEvent;
  const frames = payload.stacktrace?.frames;
  const filenames = frames?.map((f: { filename?: string }) => f.filename) ?? [];
  const frameSummary =
    frames?.map((f: { filename?: string; lineno?: number; colno?: number; function?: string }, i: number) => {
      const fn = f.function ?? '';
      return `[${i}] ${f.filename ?? '?'}:${f.lineno ?? '?'}:${f.colno ?? '?'} ${fn}`;
    }) ?? [];

  ORIGINAL_CONSOLE.info(
    `[Faro diagnostics][exception] meta.app.bundleId=${
      bundleId ?? '(missing)'
    } releaseBuild=${__DEV__ ? 'false' : 'true'} frameCount=${frames?.length ?? 0}\n` +
      `  filenames=${JSON.stringify(filenames)}\n` +
      `  frames=${frameSummary.join(' | ')}`,
  );

  const framesJson = JSON.stringify(frames ?? []);
  logChunked('[Faro diagnostics][exception-frames-json]', framesJson);

  return item;
}

let faroInitialized = false;

export async function initFaro(): Promise<void> {
  // Skip if already initialized (e.g. when app is resumed from background)
  if (faroInitialized) {
    ORIGINAL_CONSOLE.info('[Faro] Already initialized, skipping');
    return;
  }

  const collectorUrl = getFaroCollectorUrl();
  const apiKey = extractTokenFromCollectorUrl(collectorUrl);

  const config = {
    app: {
      name: FARO_APP_NAME,
      version: APP_VERSION,
      environment: APP_ENV,
    },
    /**
     * Hermes release stacks: must match Metro `sourceMapFile` / source map `file` (see `metro.config.js`).
     * Android assets are typically `index.android.bundle`; iOS is often `main.jsbundle`.
     */
    releaseBundleFilename:
      Platform.OS === 'ios' ? 'main.jsbundle' : 'index.android.bundle',
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

    beforeSend: ENABLE_FARO_PAYLOAD_DIAGNOSTICS ? faroPayloadDiagnosticsBeforeSend : undefined,
  } as ReactNativeConfig;
  const faro = await initializeFaro(config);

  // When Faro is already registered, initializeFaro logs an error and returns undefined
  // (it does not throw). Mark as initialized to avoid retry loops on app resume.
  if (!faro?.api) {
    faroInitialized = true;
    return;
  }

  if (ENABLE_FARO_PAYLOAD_DIAGNOSTICS) {
    const preambleKey = `__faroBundleId_${FARO_APP_NAME}`;
    const preambleRaw = (globalThis as Record<string, unknown>)[preambleKey];
    const metaBundleId = faro.metas.value.app?.bundleId;
    const releaseFilename =
      Platform.OS === 'ios' ? 'main.jsbundle' : 'index.android.bundle';

    const preambleStr =
      preambleRaw !== undefined ? JSON.stringify(preambleRaw) : '(undefined)';
    ORIGINAL_CONSOLE.info(
      `[Faro diagnostics][init] metroPreamble globalThis[${preambleKey}]=${preambleStr} ` +
        `meta.app.bundleId=${metaBundleId ?? '(missing)'} ` +
        `releaseBundleFilename(config)=${releaseFilename} __DEV__=${String(__DEV__)}`,
    );
  }

  // At this point, all instrumentations including SessionInstrumentation are fully initialized
  // and the session is available for error reporting
  faro.api.pushEvent('faro_initialized', {
    timestamp: new Date().toISOString(),
  });
  

  faroInitialized = true;
}
