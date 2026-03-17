import { UserActionImportance } from '@grafana/faro-core';

import { faro } from '@grafana/faro-react-native';

export function startUserAction(
  name: string,
  options?: { attributes?: Record<string, string>; isCritical?: boolean },
): void {
  if (!faro?.api) return;

  const attributes = options?.attributes ?? {};
  faro.api.startUserAction(name, attributes, {
    ...(options?.isCritical && { importance: UserActionImportance.Critical }),
  });
}
