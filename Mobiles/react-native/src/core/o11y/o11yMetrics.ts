import { faro } from '@grafana/faro-react-native';

export function addMeasurement(
  name: string,
  values: Record<string, number>,
): void {
  if (!faro?.api) return;

  faro.api.pushMeasurement({
    type: name,
    values,
  });
}
