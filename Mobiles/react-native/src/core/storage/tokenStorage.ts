import AsyncStorage from '@react-native-async-storage/async-storage';

const TOKEN_KEY = 'auth_token';
const USERNAME_KEY = 'auth_username';

export interface StoredSession {
  token: string | null;
  username: string | null;
}

export function isValidSession(session: StoredSession): boolean {
  return session.token != null && session.username != null;
}

export async function saveSession(token: string, username: string): Promise<void> {
  await AsyncStorage.multiSet([
    [TOKEN_KEY, token],
    [USERNAME_KEY, username],
  ]);
}

export async function loadSession(): Promise<StoredSession> {
  const [[, token], [, username]] = await AsyncStorage.multiGet([TOKEN_KEY, USERNAME_KEY]);
  return { token, username };
}

export async function clearSession(): Promise<void> {
  await AsyncStorage.multiRemove([TOKEN_KEY, USERNAME_KEY]);
}
