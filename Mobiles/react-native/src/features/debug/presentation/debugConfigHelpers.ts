import {
  getBundledRuntimeConfig,
  getRuntimeConfig,
} from '../../../core/config/configService';
import type { DebugSettings } from '../domain/debugSettingsStore';

export function normalizeUrl(value: string): string {
  return value.trim().replace(/\/$/, '');
}

export function maskCollectorUrl(value: string): string {
  return value.replace(/(\/collect\/).+$/, '$1...');
}

export function hasRestartRequired(settings: DebugSettings): boolean {
  const active = getRuntimeConfig();
  const bundled = getBundledRuntimeConfig();
  const nextBaseUrl = settings.backendUrlOverride
    ? normalizeUrl(settings.backendUrlOverride)
    : bundled.baseUrl;
  const nextCollectorUrl =
    settings.faroCollectorUrlOverride || bundled.faroCollectorUrl;

  return (
    nextBaseUrl !== active.baseUrl ||
    nextCollectorUrl !== active.faroCollectorUrl
  );
}

export function hasActiveDebugSettings(settings: DebugSettings): boolean {
  return (
    settings.backendUrlOverride.length > 0 ||
    settings.faroCollectorUrlOverride.length > 0 ||
    settings.backendSlowRecommendations ||
    settings.backendErrorRecommendations ||
    settings.backendSlowIngredients ||
    settings.backendErrorIngredients ||
    settings.clientFaultyPizzaJson ||
    settings.clientSkipAuthDependency
  );
}
