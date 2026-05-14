const fs = require('fs');
const path = require('path');
const { getDefaultConfig, mergeConfig } = require('@react-native/metro-config');
const withFaroConfig = require('@grafana/faro-metro-plugin').default;

/**
 * Basename (no path) for the source map top-level `file` field and upload temp map name.
 * Must match `releaseBundleFilename` in `initializeFaro` for symbolication.
 * There is no `npx react-native bundle` flag for this — set it here (or via FARO_SOURCEMAP_FILE for per-platform CI).
 * Android release bundles often use `index.android.bundle`; iOS often uses `main.jsbundle`.
 *
 * Xcode sets PLATFORM_NAME (e.g. iphoneos, iphonesimulator) during the Bundle React Native
 * script; it does not set FARO_PLATFORM. Without detecting iOS here, Metro would label maps as
 * `index.android.bundle` while devices report `main.jsbundle`, breaking Hermes compose + FE O11y symbolication for iOS.
 */
const xcPlatform = (process.env.PLATFORM_NAME || '').toLowerCase();
const isIosBundlePlatform =
  process.env.FARO_PLATFORM === 'ios' ||
  xcPlatform.includes('iphone') ||
  xcPlatform.includes('ipad');
const defaultSourceMapFile =
  process.env.FARO_SOURCEMAP_FILE ||
  (isIosBundlePlatform ? 'main.jsbundle' : 'index.android.bundle');

/** Non-secret Faro source map API settings; override per key with env if needed (CI). */
function loadSourcemapsConfig() {
  const configPath = path.join(__dirname, 'sourcemaps.config.json');
  if (!fs.existsSync(configPath)) {
    throw new Error(
      'Missing sourcemaps.config.json — copy sourcemaps.config.example.json and fill appId, stackId, endpoint.'
    );
  }
  const raw = fs.readFileSync(configPath, 'utf8');
  const parsed = JSON.parse(raw);
  if (!parsed.appName || typeof parsed.appName !== 'string') {
    throw new Error('sourcemaps.config.json: "appName" is required and must match initializeFaro app.name');
  }
  const apiKey = typeof parsed.apiKey === 'string' ? parsed.apiKey : '';
  const bundleId =
    typeof parsed.bundleId === 'string' && String(parsed.bundleId).trim() !== ''
      ? String(parsed.bundleId).trim()
      : undefined;
  return {
    appName: parsed.appName,
    endpoint: typeof parsed.endpoint === 'string' ? parsed.endpoint : '',
    appId: typeof parsed.appId === 'string' ? parsed.appId : '',
    stackId: typeof parsed.stackId === 'string' ? parsed.stackId : '',
    apiKey,
    bundleId,
  };
}

const sourcemapsStatic = loadSourcemapsConfig();

/** Same rule as `@grafana/faro-bundlers-shared` `cleanAppName` / `exportBundleIdToFile`. */
function cleanAppNameForFaro(appName) {
  return appName.toUpperCase().replace(/[^A-Z0-9]/g, '_');
}

/**
 * Matches the web bundler pattern: `FARO_BUNDLE_ID` first, then per-app
 * `FARO_BUNDLE_ID_${cleanAppName(appName)}` (the latter is what lands in `.env.QUICKPIZZA_REACTNATIVE`
 * when using `skipUpload` + `exportBundleIdToFile` on Webpack/Rollup).
 */
function resolveFaroBundleId(appName, bundleIdFromFile) {
  const generic = process.env.FARO_BUNDLE_ID;
  if (generic != null && String(generic).trim() !== '') {
    return String(generic).trim();
  }
  const perAppKey = `FARO_BUNDLE_ID_${cleanAppNameForFaro(appName)}`;
  const perApp = process.env[perAppKey];
  if (perApp != null && String(perApp).trim() !== '') {
    return String(perApp).trim();
  }
  if (bundleIdFromFile != null && String(bundleIdFromFile).trim() !== '') {
    return String(bundleIdFromFile).trim();
  }
  return undefined;
}

/**
 * Metro + Faro source maps (Hermes release). Static ids live in `sourcemaps.config.json` (see example file).
 * Optional file fields: `apiKey`, `bundleId`. Env wins: FARO_SOURCEMAP_API_KEY, FARO_BUNDLE_ID, FARO_BUNDLE_ID_<CLEAN_APP_NAME>.
 * Env FARO_SOURCEMAP_ENDPOINT | _APP_ID | _STACK_ID override JSON when set (e.g. CI).
 */
const faroMetroOpts = {
  appName: sourcemapsStatic.appName,
  endpoint: process.env.FARO_SOURCEMAP_ENDPOINT || sourcemapsStatic.endpoint,
  appId: process.env.FARO_SOURCEMAP_APP_ID || sourcemapsStatic.appId,
  stackId: process.env.FARO_SOURCEMAP_STACK_ID || sourcemapsStatic.stackId,
  apiKey: process.env.FARO_SOURCEMAP_API_KEY || sourcemapsStatic.apiKey || '',
  bundleId: resolveFaroBundleId(sourcemapsStatic.appName, sourcemapsStatic.bundleId),
  verbose: process.env.FARO_METRO_VERBOSE === '1',
  gzipContents: true,
  /** Align with `--bundle-output …/index.android.bundle` (Android) or set FARO_SOURCEMAP_FILE / FARO_PLATFORM=ios. */
  sourceMapFile: defaultSourceMapFile,
};

/**
 * @type {import('@react-native/metro-config').MetroConfig}
 */
const config = mergeConfig(getDefaultConfig(__dirname), withFaroConfig({}, faroMetroOpts));

module.exports = config;
