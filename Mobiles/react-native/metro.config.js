const fs = require('fs');
const path = require('path');
const { getDefaultConfig, mergeConfig } = require('@react-native/metro-config');
const { default: withFaroConfig, isIosBundleContext } = require('@grafana/faro-metro-plugin');

/**
 * Basename (no path) for the source map top-level `file` field and upload temp map name.
 * Must match `releaseBundleFilename` in `initializeFaro` for symbolication.
 * Xcode sets PLATFORM_NAME during the Bundle React Native script; use FARO_PLATFORM=ios when bundling for iOS outside Xcode.
 */
const defaultSourceMapFile =
  process.env.FARO_SOURCEMAP_FILE ||
  (isIosBundleContext() ? 'main.jsbundle' : 'index.android.bundle');

/** Must match `FARO_APP_NAME` in `src/bootstrap.ts` and `initializeFaro` `app.name`. */
const DEFAULT_FARO_APP_NAME = 'QuickPizza_ReactNative';

/** Non-secret Faro source map API settings; override per key with env if needed (CI). */
function loadSourcemapsConfig() {
  const configPath = path.join(__dirname, 'sourcemaps.config.json');
  if (!fs.existsSync(configPath)) {
    return {
      appName: DEFAULT_FARO_APP_NAME,
      endpoint: '',
      appId: '',
      stackId: '',
      apiKey: '',
    };
  }
  const raw = fs.readFileSync(configPath, 'utf8');
  const parsed = JSON.parse(raw);
  const appName =
    typeof parsed.appName === 'string' && parsed.appName.trim() !== ''
      ? parsed.appName.trim()
      : DEFAULT_FARO_APP_NAME;
  const apiKey = typeof parsed.apiKey === 'string' ? parsed.apiKey : '';
  return {
    appName,
    endpoint: typeof parsed.endpoint === 'string' ? parsed.endpoint : '',
    appId: typeof parsed.appId === 'string' ? parsed.appId : '',
    stackId: typeof parsed.stackId === 'string' ? parsed.stackId : '',
    apiKey,
  };
}

const sourcemapsStatic = loadSourcemapsConfig();

/**
 * Metro + Faro source maps (Hermes release).
 * Android release bundleId is resolved inside @grafana/faro-metro-plugin from the Faro Gradle
 * plugin file (applicationId@versionCode@versionName) — omit bundleId here.
 * Env overrides for upload API only: FARO_SOURCEMAP_*.
 */
const faroMetroOpts = {
  appName: sourcemapsStatic.appName,
  endpoint: process.env.FARO_SOURCEMAP_ENDPOINT || sourcemapsStatic.endpoint,
  appId: process.env.FARO_SOURCEMAP_APP_ID || sourcemapsStatic.appId,
  stackId: process.env.FARO_SOURCEMAP_STACK_ID || sourcemapsStatic.stackId,
  apiKey: process.env.FARO_SOURCEMAP_API_KEY || sourcemapsStatic.apiKey || '',
  verbose: process.env.FARO_METRO_VERBOSE === '1',
  gzipContents: true,
  sourceMapFile: defaultSourceMapFile,
};

/**
 * @type {import('@react-native/metro-config').MetroConfig}
 */
const config = mergeConfig(getDefaultConfig(__dirname), withFaroConfig({}, faroMetroOpts));

module.exports = config;
