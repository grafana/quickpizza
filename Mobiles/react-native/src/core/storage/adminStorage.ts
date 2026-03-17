import AsyncStorage from '@react-native-async-storage/async-storage';

const ADMIN_TOKEN_KEY = 'admin_token';

export async function saveAdminToken(token: string): Promise<void> {
  await AsyncStorage.setItem(ADMIN_TOKEN_KEY, token);
}

export async function loadAdminToken(): Promise<string | null> {
  return AsyncStorage.getItem(ADMIN_TOKEN_KEY);
}

export async function clearAdminToken(): Promise<void> {
  await AsyncStorage.removeItem(ADMIN_TOKEN_KEY);
}
