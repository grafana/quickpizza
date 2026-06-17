import { pathToFileURL } from 'node:url';

const DEFAULT_VARIANTS = 3;

function hourBucketForDate(now) {
  return [
    now.getUTCFullYear().toString().padStart(4, '0'),
    (now.getUTCMonth() + 1).toString().padStart(2, '0'),
    now.getUTCDate().toString().padStart(2, '0'),
    now.getUTCHours().toString().padStart(2, '0'),
  ].join('');
}

function stableHash(input) {
  let hash = 5381;
  for (let i = 0; i < input.length; i += 1) {
    hash = ((hash << 5) + hash) ^ input.charCodeAt(i);
    hash &= 0x7fffffff;
  }
  return hash;
}

export function resolveDemoAppVersion(baseVersion, { now = new Date(), variants = DEFAULT_VARIANTS } = {}) {
  const match = /^(\d+)\.(\d+)\.(\d+)$/.exec(baseVersion);
  if (!match || !Number.isFinite(variants) || variants < 1) {
    return baseVersion;
  }

  const [major, minor, patch] = match.slice(1).map(Number);
  const variant = stableHash(`${baseVersion}|${hourBucketForDate(now)}`) % variants;
  return `${major}.${minor}.${patch + variant}`;
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  const baseVersion = process.argv[2] ?? '1.0.0';
  const variants = Number.parseInt(process.env.DEMO_APP_VERSION_VARIANTS ?? `${DEFAULT_VARIANTS}`, 10);

  console.log(resolveDemoAppVersion(baseVersion, { variants }));
}
