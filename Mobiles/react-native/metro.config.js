const { getDefaultConfig } = require('@react-native/metro-config');
const path = require('path');

/**
 * Metro configuration
 * @type {import('@react-native/metro-config').MetroConfig}
 */
const config = getDefaultConfig(__dirname);

// Path to the faro-react-native-sdk monorepo root
const faroSdkRoot = path.resolve(__dirname, '../../../faro-react-native-sdk');

// Watch the SDK source files for hot reload during development
config.watchFolders = [
  path.join(faroSdkRoot, 'packages/react-native/src'),
  path.join(faroSdkRoot, 'packages/react-native-tracing/src'),
];

module.exports = config;
