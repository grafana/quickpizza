import { apiPost } from '../../../core/api/apiClient';
import * as tokenStorage from '../../../core/storage/tokenStorage';

export async function login(username: string, password: string): Promise<boolean> {
  try {
    const response = await apiPost(
      '/api/users/token/login',
      { username, password },
      { includeAuth: false },
    );

    if (response.ok) {
      const json = (await response.json()) as { token?: string };
      const token = json.token;
      if (token) {
        await tokenStorage.saveSession(token, username);
        return true;
      }
    }
    return false;
  } catch {
    return false;
  }
}

export async function logout(): Promise<void> {
  await tokenStorage.clearSession();
}

export async function loadSession(): Promise<tokenStorage.StoredSession> {
  return tokenStorage.loadSession();
}
