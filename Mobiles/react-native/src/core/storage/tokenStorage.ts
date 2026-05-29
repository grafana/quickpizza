import AsyncStorage from '@react-native-async-storage/async-storage';
import * as Keychain from 'react-native-keychain';

const KEYCHAIN_SERVICE = 'com.grafana.quickpizza.auth';
const USERNAME_KEY = 'auth_username';

export interface StoredSession {
  token: string | null;
  username: string | null;
}

export function isValidSession(session: StoredSession): boolean {
  return session.token != null && session.username != null;
}

export async function saveSession(token: string, username: string): Promise<void> {
  await Keychain.setGenericPassword(username, token, { service: KEYCHAIN_SERVICE });
  await AsyncStorage.setItem(USERNAME_KEY, username);
}

export async function loadSession(): Promise<StoredSession> {
  const credentials = await Keychain.getGenericPassword({ service: KEYCHAIN_SERVICE });
  const username =
    credentials ? credentials.username : await AsyncStorage.getItem(USERNAME_KEY);
  const token = credentials ? credentials.password : null;
  return { token, username };
}

export async function clearSession(): Promise<void> {
  await Keychain.resetGenericPassword({ service: KEYCHAIN_SERVICE });
  await AsyncStorage.removeItem(USERNAME_KEY);
}
