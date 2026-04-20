import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/config_service.dart';
import '../../../core/config/debug_settings.dart';
import '../../../core/config/runtime_config.dart';

// =============================================================================
// UI State
// =============================================================================

/// UI state for the restart-required banner, derived from the difference
/// between currently-in-use URLs (captured at bootstrap in [RuntimeConfig])
/// and the overrides saved in [DebugSettings].
class RestartBannerUiState extends Equatable {
  const RestartBannerUiState({
    required this.isVisible,
    required this.changedLabel,
  });

  const RestartBannerUiState.hidden() : isVisible = false, changedLabel = '';

  /// Whether the banner should be rendered.
  final bool isVisible;

  /// Human-readable summary of what changed, e.g. `"Backend URL"` or
  /// `"Backend URL and Faro collector URL"`. Empty when [isVisible] is false.
  final String changedLabel;

  @override
  List<Object?> get props => [isVisible, changedLabel];
}

// =============================================================================
// Provider
// =============================================================================

/// Pure derived state — no actions, no mutable state. A plain [Provider]
/// is the right tool here; a [Notifier] would be ceremony.
final restartBannerUiStateProvider = Provider<RestartBannerUiState>((ref) {
  final settings = ref.watch(debugSettingsProvider);
  final runtime = ref.watch(runtimeConfigProvider).requireValue;
  final configService = ref.watch(configServiceProvider);

  final savedBackend = settings.backendUrlOverride ?? configService.baseUrl;
  final savedFaroCollector =
      settings.faroCollectorUrlOverride ?? _safeDefaultFaroCollectorUrl();

  final backendChanged = savedBackend != runtime.backendBaseUrl;
  final faroCollectorChanged =
      savedFaroCollector != null &&
      savedFaroCollector != runtime.faroCollectorUrl;

  if (!backendChanged && !faroCollectorChanged) {
    return const RestartBannerUiState.hidden();
  }

  return RestartBannerUiState(
    isVisible: true,
    changedLabel: [
      if (backendChanged) 'Backend URL',
      if (faroCollectorChanged) 'Faro collector URL',
    ].join(' and '),
  );
});

/// [ConfigService.faroCollectorUrl] throws if `FARO_COLLECTOR_URL` isn't
/// configured. Swallow that here so the banner computation is still safe.
String? _safeDefaultFaroCollectorUrl() {
  try {
    return ConfigService.faroCollectorUrl;
  } catch (_) {
    return null;
  }
}

// =============================================================================
// Widget
// =============================================================================

/// Shown at the top of the Debug and Config screens whenever the saved
/// URL overrides differ from the URLs currently-in-use in the session.
///
/// Returns a zero-size widget when no restart is needed.
class RestartRequiredBanner extends ConsumerWidget {
  const RestartRequiredBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uiState = ref.watch(restartBannerUiStateProvider);

    if (!uiState.isVisible) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Card(
        color: Colors.amber.shade100,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.amber.shade900),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Restart required',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.amber.shade900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Kill and relaunch the app for the new '
                      '${uiState.changedLabel} to take effect.',
                      style: TextStyle(color: Colors.amber.shade900),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
