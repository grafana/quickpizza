const DEFAULT_APP_VERSION = '1.0.0';
const APP_VERSION_PATTERN = /^\d+\.\d+\.\d+$/;

export function resolveTelemetryAppVersion(demoAppVersion?: string): string {
  const trimmed = demoAppVersion?.trim();
  if (trimmed && APP_VERSION_PATTERN.test(trimmed)) {
    return trimmed;
  }
  return DEFAULT_APP_VERSION;
}
