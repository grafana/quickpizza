import { faro } from '@grafana/faro-react-native';

export function reportError(options: {
  type: string;
  error: string;
  stacktrace?: string;
  context?: Record<string, string>;
}): void {
  if (!faro?.api) return;

  const context: Record<string, string> = { ...options.context };
  if (options.stacktrace) {
    context.stacktrace = options.stacktrace;
  }
  faro.api.pushError(new Error(options.error), {
    type: options.type,
    context,
  });
}
