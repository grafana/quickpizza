/// Utility functions for Grafana Faro configuration
library;

/// Extracts the API key token from a Grafana Faro collector URL.
///
/// The token is expected to be the path segment immediately after `/collect/`.
/// Format: https://domain/collect/TOKEN
///
/// Returns an empty string if:
/// - The URL is null or empty
/// - The URL doesn't contain `/collect/`
/// - The token segment is empty
/// - URL parsing fails
String extractTokenFromCollectorUrl(String? collectorUrl) {
  if (collectorUrl == null || collectorUrl.isEmpty) {
    return '';
  }

  try {
    final uri = Uri.parse(collectorUrl);
    final pathSegments = uri.pathSegments;
    final collectIndex = pathSegments.indexOf('collect');
    if (collectIndex != -1 && collectIndex + 1 < pathSegments.length) {
      final token = pathSegments[collectIndex + 1];
      if (token.isNotEmpty) {
        return token;
      }
    }
  } catch (e) {
    return '';
  }

  return '';
}
