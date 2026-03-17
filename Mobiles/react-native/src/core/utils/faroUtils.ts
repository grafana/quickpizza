/**
 * Extracts the API key token from a Grafana Faro collector URL.
 * Format: https://domain/collect/TOKEN
 */
export function extractTokenFromCollectorUrl(collectorUrl: string | undefined): string {
  if (!collectorUrl || collectorUrl.trim().length === 0) {
    return '';
  }

  try {
    const url = new URL(collectorUrl);
    const segments = url.pathname.split('/').filter(Boolean);
    const collectIndex = segments.indexOf('collect');
    if (collectIndex !== -1 && collectIndex + 1 < segments.length) {
      const token = segments[collectIndex + 1];
      if (token && token.length > 0) {
        return token;
      }
    }
  } catch {
    return '';
  }

  return '';
}
