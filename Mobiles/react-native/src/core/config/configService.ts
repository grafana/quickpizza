import { Platform } from 'react-native';

interface AppConfig {
  FARO_COLLECTOR_URL?: string;
  BASE_URL?: string;
  PORT?: string;
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
