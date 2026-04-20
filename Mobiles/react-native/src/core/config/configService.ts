import { Platform } from 'react-native';

interface AppConfig {
  FARO_COLLECTOR_URL?: string;
  BASE_URL?: string;
  PORT?: string;
  /**
   * When true: 
   *    (1) a background GET /api/ingredients/topping sends x-error-get-ingredients (catalog injects failure); 
   *    (2) "No thanks" throws after a successful rating.
   */
  SIMULATE_DEMO_ERROR?: boolean | string;
}

function isTruthyConfigFlag(value: boolean | string | undefined): boolean {
  if (value === true) {
    return true;
  }
  if (typeof value === 'string') {
    const s = value.trim().toLowerCase();
    return s === 'true' || s === '1' || s === 'yes';
  }
  return false;
}

/** Single switch for FEO/backend demo errors (API injection + No thanks client error). */
export function isSimulateDemoErrorEnabled(): boolean {
  return isTruthyConfigFlag(config.SIMULATE_DEMO_ERROR);
}

const GET_INGREDIENTS_DEMO_MESSAGE =
  'FEO demo: get ingredients for topping failure for demo purpose';

function loadConfig(): AppConfig {
  try {
    return require('../../../config.json') as AppConfig;
  } catch {
    return {};
  }
}

const config = loadConfig();
const DEFAULT_PORT = '3333';

function getBaseUrl(): string {
  const configured = config.BASE_URL ?? '';
  if (configured && configured.trim().length > 0) {
    return configured.trim().replace(/\/$/, '');
  }

  const port = config.PORT ?? DEFAULT_PORT;
  if (Platform.OS === 'android') {
    return `http://10.0.2.2:${port}`;
  }
  return `http://localhost:${port}`;
}

export function getBaseUrlConfig(): string {
  return getBaseUrl();
}

export function getFaroCollectorUrl(): string {
  const collectorUrl = config.FARO_COLLECTOR_URL ?? '';
  if (!collectorUrl || collectorUrl.trim().length === 0) {
    throw new Error(
      [
        'FARO_COLLECTOR_URL is not configured!',
        '',
        'This demo app requires Faro for observability.',
        '',
        'To fix:',
        '1. Copy config.json.example to config.json',
        '2. Set your FARO_COLLECTOR_URL in config.json',
        '3. Rebuild the app',
      ].join('\n'),
    );
  }
  return collectorUrl.trim();
}

export function getConfig() {
  return {
    baseUrl: getBaseUrl(),
    faroCollectorUrl: getFaroCollectorUrl(),
    port: config.PORT ?? DEFAULT_PORT,
  };
}

export function getApiBaseUrl(): string {
  return getBaseUrl();
}

/**
 * URL patterns for OpenTelemetry fetch instrumentation to inject W3C `traceparent` on outbound
 * requests. Matches the QuickPizza API origin from {@link getBaseUrlConfig} (localhost, 10.0.2.2,
 * or custom `BASE_URL` in config.json).
 *
 * Includes common dev aliases (127.0.0.1, ::1) so propagation still applies if `BASE_URL` uses
 * one host while `fetch` resolves another — otherwise the backend starts a new trace id.
 */
export function getQuickPizzaTracePropagationUrlPatterns(): Array<string | RegExp> {
  const base = getBaseUrl().replace(/\/$/, '');
  const escaped = base.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
  const port = String(config.PORT ?? DEFAULT_PORT).trim();
  return [
    new RegExp(`^${escaped}`),
    new RegExp(`^https?://localhost:${port}(?:/|$)`),
    new RegExp(`^https?://127\\.0\\.0\\.1:${port}(?:/|$)`),
    new RegExp(`^https?://\\[::1\\]:${port}(?:/|$)`),
    new RegExp(`^http://10\\.0\\.2\\.2:${port}(?:/|$)`),
  ];
}

/**
 * Headers for QuickPizza catalog GET /api/ingredients/{type} error injection
 * (`pkg/database/catalog.go` → InjectErrors "get-ingredients").
 */
export function getIngredientsDemoErrorHeaders():
  | Record<string, string>
  | undefined {
  if (!isSimulateDemoErrorEnabled()) {
    return undefined;
  }
  return { 'x-error-get-ingredients': GET_INGREDIENTS_DEMO_MESSAGE };
}
