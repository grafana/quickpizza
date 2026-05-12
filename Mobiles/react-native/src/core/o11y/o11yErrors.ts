import { faro } from '@grafana/faro-react-native';

export function reportError(options: {
  type: string;
  error: string;
  stacktrace?: string;
  context?: Record<string, string>;
}): void {
  if (!faro?.api) return;

  const context: Record<string, string> = { ...options.context };
  const err = new Error(options.error);
  /**
   * Faro builds `stacktrace.frames` from `error.stack` via `parseStacktrace`.
   * Assigning the caught stack here ensures handled exceptions use the real Hermes positions
   * for symbolification — not the shallow stack from `new Error()` inside this helper.
   */
  if (options.stacktrace) {
    err.stack = options.stacktrace;
  }

  faro.api.pushError(err, {
    type: options.type,
    context,
  });
}
