import { getApiBaseUrl } from '../config/configService';

const TIMEOUT_MS = 10000;

export type GetTokenFn = () => Promise<string | null>;

let getTokenFn: GetTokenFn = async () => null;

export function setApiClientTokenGetter(fn: GetTokenFn): void {
  getTokenFn = fn;
}

async function getHeaders(includeAuth: boolean): Promise<Record<string, string>> {
  const headers: Record<string, string> = {
    'Content-Type': 'application/json',
  };

  if (includeAuth) {
    const token = await getTokenFn();
    if (token) {
      headers['Authorization'] = `Token ${token}`;
    }
  }

  return headers;
}

export async function apiGet(
  endpoint: string,
  _endpointName?: string,
): Promise<Response> {
  const baseUrl = getApiBaseUrl();

  const headers = await getHeaders(true);
  const controller = new AbortController();
  const timeoutId = setTimeout(() => controller.abort(), TIMEOUT_MS);

  const response = await fetch(`${baseUrl}${endpoint}`, {
    method: 'GET',
    headers,
    signal: controller.signal,
  });

  clearTimeout(timeoutId);
  return response;
}

export async function apiPost(
  endpoint: string,
  body?: unknown,
  options?: { includeAuth?: boolean },
): Promise<Response> {
  const baseUrl = getApiBaseUrl();
  const includeAuth = options?.includeAuth ?? true;

  const headers = await getHeaders(includeAuth);
  const controller = new AbortController();
  const timeoutId = setTimeout(() => controller.abort(), TIMEOUT_MS);

  const response = await fetch(`${baseUrl}${endpoint}`, {
    method: 'POST',
    headers,
    body: body != null ? JSON.stringify(body) : undefined,
    signal: controller.signal,
  });

  clearTimeout(timeoutId);
  return response;
}

export async function apiDelete(endpoint: string): Promise<Response> {
  const baseUrl = getApiBaseUrl();

  const headers = await getHeaders(true);
  const controller = new AbortController();
  const timeoutId = setTimeout(() => controller.abort(), TIMEOUT_MS);

  const response = await fetch(`${baseUrl}${endpoint}`, {
    method: 'DELETE',
    headers,
    signal: controller.signal,
  });

  clearTimeout(timeoutId);
  return response;
}
