import { faro, LogLevel } from '@grafana/faro-react-native';

function pushLog(
  message: string,
  level: LogLevel,
  context?: Record<string, string>,
): void {
  if (!faro?.api) return;

  faro.api.pushLog([message], {
    context,
    level,
  });
}

export function pushDebugLog(
  message: string,
  context?: Record<string, string>,
): void {
  pushLog(message, LogLevel.DEBUG, context);
}

export function pushErrorLog(
  message: string,
  context?: Record<string, string>,
): void {
  pushLog(message, LogLevel.ERROR, context);
}
