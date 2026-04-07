import { getApiBaseUrl } from '../config/configService';

const TIMEOUT_MS = 10000;

export interface AdminPizza {
  id: number;
  name: string;
  dough: { id: number; name: string };
  ingredients: Array<{ id: number; name: string }>;
  tool: string;
}

export interface AdminRecommendationsResponse {
  pizzas: AdminPizza[];
}

export async function adminLogin(
  username: string,
  password: string,
): Promise<{ token: string } | null> {
  const baseUrl = getApiBaseUrl();
  const url = `${baseUrl}/api/admin/login?user=${encodeURIComponent(username)}&password=${encodeURIComponent(password)}`;

  const controller = new AbortController();
  const timeoutId = setTimeout(() => controller.abort(), TIMEOUT_MS);

  try {
    const response = await fetch(url, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      signal: controller.signal,
    });

    clearTimeout(timeoutId);

    if (!response.ok) {
      return null;
    }

    const json = (await response.json()) as { token?: string };
    return json.token ? { token: json.token } : null;
  } catch {
    clearTimeout(timeoutId);
    return null;
  }
}

export async function getAdminRecommendations(
  adminToken: string,
): Promise<AdminRecommendationsResponse | null> {
  const baseUrl = getApiBaseUrl();
  const url = `${baseUrl}/api/internal/recommendations`;

  const controller = new AbortController();
  const timeoutId = setTimeout(() => controller.abort(), TIMEOUT_MS);

  try {
    const response = await fetch(url, {
      method: 'GET',
      headers: {
        'Content-Type': 'application/json',
        Cookie: `admin_token=${adminToken}`,
      },
      signal: controller.signal,
    });

    clearTimeout(timeoutId);

    if (!response.ok) {
      return null;
    }

    const json = (await response.json()) as AdminRecommendationsResponse;
    return json;
  } catch {
    clearTimeout(timeoutId);
    return null;
  }
}
