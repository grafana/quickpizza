const baseVersion = process.argv[2] ?? '1.0.0';
const variants = Number.parseInt(process.env.DEMO_APP_VERSION_VARIANTS ?? '3', 10);

const match = /^(\d+)\.(\d+)\.(\d+)$/.exec(baseVersion);
if (!match || !Number.isFinite(variants) || variants < 1) {
  console.log(baseVersion);
  process.exit(0);
}

const [major, minor, patch] = match.slice(1).map(Number);
const now = new Date();
const hourBucket = [
  now.getUTCFullYear().toString().padStart(4, '0'),
  (now.getUTCMonth() + 1).toString().padStart(2, '0'),
  now.getUTCDate().toString().padStart(2, '0'),
  now.getUTCHours().toString().padStart(2, '0'),
].join('');

function stableHash(input) {
  let hash = 5381;
  for (let i = 0; i < input.length; i += 1) {
    hash = ((hash << 5) + hash) ^ input.charCodeAt(i);
    hash &= 0x7fffffff;
  }
  return hash;
}

const variant = stableHash(`${baseVersion}|${hourBucket}`) % variants;
console.log(`${major}.${minor}.${patch + variant}`);
