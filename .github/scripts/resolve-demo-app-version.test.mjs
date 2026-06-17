import assert from 'node:assert/strict';
import { describe, it } from 'node:test';

import { resolveDemoAppVersion } from './resolve-demo-app-version.mjs';

describe('resolveDemoAppVersion', () => {
  const hour = new Date(Date.UTC(2026, 5, 17, 12, 34));

  it('keeps the same version variant within a UTC hour', () => {
    const first = resolveDemoAppVersion('1.0.0', { now: hour });
    const second = resolveDemoAppVersion('1.0.0', {
      now: new Date(Date.UTC(2026, 5, 17, 12, 59)),
    });

    assert.equal(first, second);
  });

  it('keeps generated patch versions within the configured variant range', () => {
    const version = resolveDemoAppVersion('1.0.4', { now: hour, variants: 3 });

    assert.match(version, /^1\.0\.[4-6]$/);
  });

  it('falls back to the base version for invalid input', () => {
    assert.equal(resolveDemoAppVersion('1.0', { now: hour }), '1.0');
    assert.equal(resolveDemoAppVersion('1.0.0', { now: hour, variants: 0 }), '1.0.0');
    assert.equal(resolveDemoAppVersion('1.0.0', { now: hour, variants: Number.NaN }), '1.0.0');
  });
});
