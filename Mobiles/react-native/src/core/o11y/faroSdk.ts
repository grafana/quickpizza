/**
 * Single import surface for @grafana/faro-* used during app bootstrap.
 * Feature and root modules should not import Faro packages directly for init.
 */
export {
  InternalLoggerLevel,
  SamplingFunction,
  SamplingRate,
  initializeFaroAsync,
  type ReactNativeConfig,
} from '@grafana/faro-react-native';
