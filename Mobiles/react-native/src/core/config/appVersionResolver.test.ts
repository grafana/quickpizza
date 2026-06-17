import { resolveTelemetryAppVersion } from './appVersionResolver';

describe('resolveTelemetryAppVersion', () => {
  it('uses the default app version when no demo version is provided', () => {
    expect(resolveTelemetryAppVersion()).toBe('1.0.0');
  });

  it('uses the CI-provided demo app version when it is valid', () => {
    expect(resolveTelemetryAppVersion('1.0.2')).toBe('1.0.2');
  });

  it('falls back to the default app version when the demo version is invalid', () => {
    expect(resolveTelemetryAppVersion('1.0')).toBe('1.0.0');
    expect(resolveTelemetryAppVersion('')).toBe('1.0.0');
  });
});
