import { getApiBaseUrl } from '../config/configService';

const TIMEOUT_MS = 10000;

export type GetTokenFn = () => Promise<string | null>;

let getTokenFn: GetTokenFn = async () => null;

export function setApiClientTokenGetter(fn: GetTokenFn): void {
  getTokenFn = fn;
}

export type ApiRequestOptions = {
  includeAuth?: boolean;
  /** Merged after Content-Type; does not replace Authorization. */
  extraHeaders?: Record<string, string>;
};

async function getHeaders(
  includeAuth: boolean,
  extraHeaders?: Record<string, string>,
): Promise<Record<string, string>> {
  const headers: Record<string, string> = {
    'Content-Type': 'application/json',
    ...(extraHeaders ?? {}),
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

  const headers = await getHeaders(true, undefined);
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
  options?: ApiRequestOptions,
): Promise<Response> {
  const baseUrl = getApiBaseUrl();
  const includeAuth = options?.includeAuth ?? true;

  const headers = await getHeaders(includeAuth, options?.extraHeaders);
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

  const headers = await getHeaders(true, undefined);
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
