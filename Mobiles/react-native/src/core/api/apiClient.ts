import { getApiBaseUrl } from '../config/configService';
import { getErrorInjectionHeaders } from '../../features/debug/domain/debugSettingsStore';

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
    ...getErrorInjectionHeaders(),
    ...(extraHeaders ?? {}),
  };

  if (includeAuth) {
    const token = await getTokenFn();
    if (token) {
      headers.Authorization = `Token ${token}`;
    }
  }

  return headers;
}

function buildApiUrl(endpoint: string): string {
  const baseUrl = getApiBaseUrl();
  const normalizedBase = baseUrl.endsWith('/') ? baseUrl : `${baseUrl}/`;
  return new URL(endpoint, normalizedBase).toString();
}

export async function apiGet(
  endpoint: string,
  _endpointName?: string,
  options?: ApiRequestOptions,
): Promise<Response> {
  const headers = await getHeaders(
    options?.includeAuth ?? true,
    options?.extraHeaders,
  );
  const controller = new AbortController();
  const timeoutId = setTimeout(() => controller.abort(), TIMEOUT_MS);

  const response = await fetch(buildApiUrl(endpoint), {
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
  const includeAuth = options?.includeAuth ?? true;

  const headers = await getHeaders(includeAuth, options?.extraHeaders);
  const controller = new AbortController();
  const timeoutId = setTimeout(() => controller.abort(), TIMEOUT_MS);

  const response = await fetch(buildApiUrl(endpoint), {
    method: 'POST',
    headers,
    body: body != null ? JSON.stringify(body) : undefined,
    signal: controller.signal,
  });

  clearTimeout(timeoutId);
  return response;
}

export async function apiDelete(endpoint: string): Promise<Response> {
  const headers = await getHeaders(true, undefined);
  const controller = new AbortController();
  const timeoutId = setTimeout(() => controller.abort(), TIMEOUT_MS);

  const response = await fetch(buildApiUrl(endpoint), {
    method: 'DELETE',
    headers,
    signal: controller.signal,
  });

  clearTimeout(timeoutId);
  return response;
}
