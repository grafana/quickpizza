import { faro } from '@grafana/faro-react-native';

export function trackEvent(name: string, context?: Record<string, string>): void {
  if (!faro?.api) return;
  faro.api.pushEvent(name, context ?? {});
}

export function setUser(user: {
  id?: string;
  username?: string;
  email?: string;
  attributes?: Record<string, string>;
}): void {
  if (!faro?.api) return;

  const hasAny = user.id ?? user.username ?? user.email ?? user.attributes;
  if (!hasAny) {
    faro.api.setUser();
    return;
  }

  faro.api.setUser({
    id: user.id,
    username: user.username,
    email: user.email,
    attributes: user.attributes,
  });
}
