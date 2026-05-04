import { Platform } from 'react-native';

import { loadSavedDebugSettings } from '../../features/debug/domain/debugSettingsStore';

interface AppConfig {
  FARO_COLLECTOR_URL?: string;
  BASE_URL?: string;
  PORT?: string;
}

export interface RuntimeConfig {
  baseUrl: string;
  faroCollectorUrl: string;
  port: string;
}

function loadConfig(): AppConfig {
  try {
    return require('../../../config.json') as AppConfig;
  } catch {
    return {};
  }
}

const config = loadConfig();
const DEFAULT_PORT = '3333';
let activeRuntimeConfig: RuntimeConfig = buildDefaultRuntimeConfig();

function normalizeUrl(value: string): string {
  return value.trim().replace(/\/$/, '');
}

function getDefaultBaseUrl(): string {
  const configured = config.BASE_URL ?? '';
  if (configured && configured.trim().length > 0) {
    return normalizeUrl(configured);
  }

  const port = config.PORT ?? DEFAULT_PORT;
  if (Platform.OS === 'android') {
    return `http://10.0.2.2:${port}`;
  }
  return `http://localhost:${port}`;
}

function getConfiguredFaroCollectorUrl(): string {
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

function buildDefaultRuntimeConfig(): RuntimeConfig {
  return {
    baseUrl: getDefaultBaseUrl(),
    faroCollectorUrl: getConfiguredFaroCollectorUrl(),
    port: config.PORT ?? DEFAULT_PORT,
  };
}

export async function initializeRuntimeConfig(): Promise<RuntimeConfig> {
  const saved = await loadSavedDebugSettings();
  const defaults = buildDefaultRuntimeConfig();
  activeRuntimeConfig = {
    baseUrl: saved.backendUrlOverride
      ? normalizeUrl(saved.backendUrlOverride)
      : defaults.baseUrl,
    faroCollectorUrl: saved.faroCollectorUrlOverride || defaults.faroCollectorUrl,
    port: defaults.port,
  };
  return activeRuntimeConfig;
}

export function getRuntimeConfig(): RuntimeConfig {
  return activeRuntimeConfig;
}

export function getBundledRuntimeConfig(): RuntimeConfig {
  return buildDefaultRuntimeConfig();
}

export function getBaseUrlConfig(): string {
  return activeRuntimeConfig.baseUrl;
}

export function getFaroCollectorUrl(): string {
  return activeRuntimeConfig.faroCollectorUrl;
}

export function getConfig() {
  return {
    ...activeRuntimeConfig,
  };
}

export function getApiBaseUrl(): string {
  return activeRuntimeConfig.baseUrl;
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
  const base = activeRuntimeConfig.baseUrl.replace(/\/$/, '');
  const escaped = base.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
  const port = String(activeRuntimeConfig.port).trim();
  return [
    new RegExp(`^${escaped}`),
    new RegExp(`^https?://localhost:${port}(?:/|$)`),
    new RegExp(`^https?://127\\.0\\.0\\.1:${port}(?:/|$)`),
    new RegExp(`^https?://\\[::1\\]:${port}(?:/|$)`),
    new RegExp(`^http://10\\.0\\.2\\.2:${port}(?:/|$)`),
  ];
}
