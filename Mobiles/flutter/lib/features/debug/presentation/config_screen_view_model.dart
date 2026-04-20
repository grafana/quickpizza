import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/config_service.dart';
import '../../../core/config/debug_settings.dart';
import '../../../core/config/runtime_config.dart';
import '../../../core/utils/faro_utils.dart';

// =============================================================================
// UI State
// =============================================================================

/// Represents the UI state for the debug Config screen.
class ConfigScreenUiState extends Equatable {
  const ConfigScreenUiState({
    required this.backendInUse,
    required this.faroCollectorInUse,
    required this.faroCollectorInUseDisplay,
    required this.defaultBackend,
    required this.defaultFaroCollector,
    required this.defaultFaroCollectorDisplay,
    required this.savedBackendOverride,
    required this.savedFaroCollectorOverride,
    required this.saving,
    required this.statusMessage,
  });

  /// Backend URL currently used by [ApiClient] for this session.
  final String backendInUse;

  /// Raw Faro collector URL currently used by Faro for this session.
  final String faroCollectorInUse;

  /// Faro collector URL with the API key partially masked, safe to render.
  final String faroCollectorInUseDisplay;

  /// Build-time default backend URL.
  final String defaultBackend;

  /// Build-time default Faro collector URL (null if not configured).
  final String? defaultFaroCollector;

  /// Masked build-time default, safe to render (null if not configured).
  final String? defaultFaroCollectorDisplay;

  /// Saved override in SharedPreferences — empty string means "no override".
  final String? savedBackendOverride;
  final String? savedFaroCollectorOverride;

  /// Whether a save/clear is in-flight.
  final bool saving;

  /// Transient status message shown to the user after a save/clear.
  final String? statusMessage;

  ConfigScreenUiState copyWith({
    bool? saving,
    String? Function()? statusMessage,
  }) {
    return ConfigScreenUiState(
      backendInUse: backendInUse,
      faroCollectorInUse: faroCollectorInUse,
      faroCollectorInUseDisplay: faroCollectorInUseDisplay,
      defaultBackend: defaultBackend,
      defaultFaroCollector: defaultFaroCollector,
      defaultFaroCollectorDisplay: defaultFaroCollectorDisplay,
      savedBackendOverride: savedBackendOverride,
      savedFaroCollectorOverride: savedFaroCollectorOverride,
      saving: saving ?? this.saving,
      statusMessage: statusMessage != null
          ? statusMessage()
          : this.statusMessage,
    );
  }

  @override
  List<Object?> get props => [
    backendInUse,
    faroCollectorInUse,
    faroCollectorInUseDisplay,
    defaultBackend,
    defaultFaroCollector,
    defaultFaroCollectorDisplay,
    savedBackendOverride,
    savedFaroCollectorOverride,
    saving,
    statusMessage,
  ];
}

// =============================================================================
// Actions Interface
// =============================================================================

/// Defines the actions available on the Config screen.
abstract interface class ConfigScreenActions {
  /// Persist both URL overrides atomically. Empty/whitespace values clear
  /// the corresponding override.
  Future<void> save({
    required String? backendUrl,
    required String? faroCollectorUrl,
  });

  /// Clear both URL overrides and fall back to build-time defaults on the
  /// next app launch.
  Future<void> clear();
}

// =============================================================================
// ViewModel Implementation
// =============================================================================

class _ConfigScreenViewModel extends Notifier<ConfigScreenUiState>
    implements ConfigScreenActions {
  @override
  ConfigScreenUiState build() {
    final settings = ref.watch(debugSettingsProvider);
    final runtime = ref.watch(runtimeConfigProvider).requireValue;
    final configService = ref.watch(configServiceProvider);

    final defaultFaroCollector = _safeDefaultFaroCollectorUrl();

    return ConfigScreenUiState(
      backendInUse: runtime.backendBaseUrl,
      faroCollectorInUse: runtime.faroCollectorUrl,
      faroCollectorInUseDisplay: maskCollectorUrl(runtime.faroCollectorUrl),
      defaultBackend: configService.baseUrl,
      defaultFaroCollector: defaultFaroCollector,
      defaultFaroCollectorDisplay: defaultFaroCollector == null
          ? null
          : maskCollectorUrl(defaultFaroCollector),
      savedBackendOverride: settings.backendUrlOverride,
      savedFaroCollectorOverride: settings.faroCollectorUrlOverride,
      saving: false,
      statusMessage: null,
    );
  }

  @override
  Future<void> save({
    required String? backendUrl,
    required String? faroCollectorUrl,
  }) async {
    state = state.copyWith(saving: true, statusMessage: () => null);
    await ref
        .read(debugSettingsProvider.notifier)
        .saveUrls(backendUrl: backendUrl, faroCollectorUrl: faroCollectorUrl);
    // State is re-derived automatically via ref.watch(debugSettingsProvider)
    // in build(), so we only need to update the transient fields here.
    state = state.copyWith(
      saving: false,
      statusMessage: () =>
          'Saved. Kill and relaunch the app for changes to take effect.',
    );
  }

  @override
  Future<void> clear() async {
    state = state.copyWith(saving: true, statusMessage: () => null);
    await ref
        .read(debugSettingsProvider.notifier)
        .saveUrls(backendUrl: null, faroCollectorUrl: null);
    state = state.copyWith(
      saving: false,
      statusMessage: () =>
          'Overrides cleared. Kill and relaunch to use defaults.',
    );
  }

  /// [ConfigService.faroCollectorUrl] throws if `FARO_COLLECTOR_URL` isn't
  /// configured. Swallow that here so the Config screen is still usable.
  String? _safeDefaultFaroCollectorUrl() {
    try {
      return ConfigService.faroCollectorUrl;
    } catch (_) {
      return null;
    }
  }
}

// =============================================================================
// Providers
// =============================================================================

final _configScreenViewModelProvider =
    NotifierProvider<_ConfigScreenViewModel, ConfigScreenUiState>(
      _ConfigScreenViewModel.new,
    );

final configScreenUiStateProvider = Provider<ConfigScreenUiState>((ref) {
  return ref.watch(_configScreenViewModelProvider);
});

final configScreenActionsProvider = Provider<ConfigScreenActions>((ref) {
  return ref.read(_configScreenViewModelProvider.notifier);
});
