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

/// Masks the API key portion of a Grafana Faro collector URL for display.
///
/// Input:  `https://host/collect/abc123def456ghi789jkl`
/// Output: `https://host/collect/abc•••••jkl`
///
/// If the key is 6 characters or shorter, it's fully replaced with bullets.
/// If the URL doesn't match the `/collect/<key>` pattern, the input is
/// returned unchanged.
///
/// Note: this is a display-only string transform. We deliberately avoid
/// round-tripping through [Uri] so that non-ASCII bullet characters
/// don't get percent-encoded.
String maskCollectorUrl(String? collectorUrl) {
  if (collectorUrl == null || collectorUrl.isEmpty) return '';

  const marker = '/collect/';
  final markerIndex = collectorUrl.indexOf(marker);
  if (markerIndex == -1) return collectorUrl;

  final keyStart = markerIndex + marker.length;
  // The key runs until the next `/`, `?`, or end-of-string.
  var keyEnd = collectorUrl.length;
  for (var i = keyStart; i < collectorUrl.length; i++) {
    final c = collectorUrl.codeUnitAt(i);
    if (c == 0x2F /* / */ || c == 0x3F /* ? */ || c == 0x23 /* # */ ) {
      keyEnd = i;
      break;
    }
  }

  final key = collectorUrl.substring(keyStart, keyEnd);
  if (key.isEmpty) return collectorUrl;

  final masked = _maskKey(key);
  return collectorUrl.substring(0, keyStart) +
      masked +
      collectorUrl.substring(keyEnd);
}

String _maskKey(String key) {
  const bullets = '•••••';
  if (key.length <= 6) return bullets;
  return '${key.substring(0, 3)}$bullets${key.substring(key.length - 3)}';
}
