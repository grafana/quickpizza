/**
 * React Native RUM primitives — all @grafana/faro-react-native UI hooks/components
 * used by the app are re-exported here so features depend on core/o11y only.
 */
export { FaroErrorBoundary as O11yErrorBoundary } from '@grafana/faro-react-native';
export {
  useFaroNavigation as useO11yNavigation,
  withFaroUserAction as withUserAction,
} from '@grafana/faro-react-native';
