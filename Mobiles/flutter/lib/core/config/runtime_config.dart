import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'backend_url_service.dart';
import 'faro_collector_service.dart';

/// Immutable snapshot of configuration values captured once at app
/// bootstrap and held for the lifetime of the session.
///
/// This is intentionally *not* reactive: these are the URLs that Faro
/// initialized with and that [ApiClient] is using. Changing a saved
/// override in [DebugSettings] will NOT change these values — the user
/// must restart the app for the override to take effect.
///
/// Why: keeping backend + collector stable per session makes correlated
/// traces/logs/metrics much easier to reason about when demoing.
class RuntimeConfig {
  const RuntimeConfig({
    required this.backendBaseUrl,
    required this.faroCollectorUrl,
  });

  final String backendBaseUrl;
  final String faroCollectorUrl;
}

/// Resolves the effective backend + Faro URLs once, via the service
/// providers. Bootstrap awaits [runtimeConfigProvider.future] before
/// running the app, so downstream consumers can safely use
/// `ref.watch(runtimeConfigProvider).requireValue` without dealing
/// with a loading state.
final runtimeConfigProvider = FutureProvider<RuntimeConfig>((ref) async {
  final backendBaseUrl = await ref.watch(backendUrlServiceProvider).getUrl();
  final faroCollectorUrl = await ref
      .watch(faroCollectorServiceProvider)
      .getUrl();
  return RuntimeConfig(
    backendBaseUrl: backendBaseUrl,
    faroCollectorUrl: faroCollectorUrl,
  );
});
