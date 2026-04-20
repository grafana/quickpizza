import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// SharedPreferences keys used by debug settings. Exposed so other
/// services (e.g. FaroCollectorService) can read the same values
/// before Riverpod is available.
abstract class DebugSettingsKeys {
  static const backendUrl = 'debug_backend_url';
  static const faroCollectorUrl = 'debug_faro_collector_url';
  static const errorRecommendations = 'debug_error_recommendations';
  static const errorIngredients = 'debug_error_ingredients';
  static const slowRecommendations = 'debug_slow_recommendations';
  static const slowIngredients = 'debug_slow_ingredients';
  static const useV2PizzaSchema = 'debug_use_v2_pizza_schema';
  static const skipAuthDepInTools = 'debug_skip_auth_dep_in_tools';
}

final debugSettingsProvider =
    NotifierProvider<DebugSettingsNotifier, DebugSettings>(
      DebugSettingsNotifier.new,
    );

class DebugSettings {
  final String? backendUrlOverride;
  final String? faroCollectorUrlOverride;
  final bool errorOnRecommendations;
  final bool errorOnIngredients;
  final bool slowRecommendations;
  final bool slowIngredients;
  final bool useV2PizzaSchema;
  final bool skipAuthDepInTools;

  const DebugSettings({
    this.backendUrlOverride,
    this.faroCollectorUrlOverride,
    this.errorOnRecommendations = false,
    this.errorOnIngredients = false,
    this.slowRecommendations = false,
    this.slowIngredients = false,
    this.useV2PizzaSchema = false,
    this.skipAuthDepInTools = false,
  });

  DebugSettings copyWith({
    String? Function()? backendUrlOverride,
    String? Function()? faroCollectorUrlOverride,
    bool? errorOnRecommendations,
    bool? errorOnIngredients,
    bool? slowRecommendations,
    bool? slowIngredients,
    bool? useV2PizzaSchema,
    bool? skipAuthDepInTools,
  }) {
    return DebugSettings(
      backendUrlOverride: backendUrlOverride != null
          ? backendUrlOverride()
          : this.backendUrlOverride,
      faroCollectorUrlOverride: faroCollectorUrlOverride != null
          ? faroCollectorUrlOverride()
          : this.faroCollectorUrlOverride,
      errorOnRecommendations:
          errorOnRecommendations ?? this.errorOnRecommendations,
      errorOnIngredients: errorOnIngredients ?? this.errorOnIngredients,
      slowRecommendations: slowRecommendations ?? this.slowRecommendations,
      slowIngredients: slowIngredients ?? this.slowIngredients,
      useV2PizzaSchema: useV2PizzaSchema ?? this.useV2PizzaSchema,
      skipAuthDepInTools: skipAuthDepInTools ?? this.skipAuthDepInTools,
    );
  }

  bool get hasActiveOverrides =>
      backendUrlOverride != null ||
      faroCollectorUrlOverride != null ||
      errorOnRecommendations ||
      errorOnIngredients ||
      slowRecommendations ||
      slowIngredients ||
      useV2PizzaSchema ||
      skipAuthDepInTools;

  /// Backend expects:
  ///  * `x-error-*` headers — value is the error message (any non-empty string)
  ///  * `x-delay-*` headers — value is a Go duration string (e.g. `3s`, `500ms`)
  ///
  /// We send descriptive messages so they're meaningful in the backend
  /// logs/traces (Loki/Tempo). The mobile UI shows a generic message — the
  /// injected text is for backend-side correlation only.
  ///
  /// Delay values are tuned so both toggles produce ~3s of user-visible
  /// slowness. `record-recommendation` is called once per `POST /api/pizza`,
  /// so 3s → ~3s. `get-ingredients` is called four times per request
  /// (oil, tomato, mozzarella, topping), so 750ms → ~3s total.
  Map<String, String> get errorInjectionHeaders {
    const recommendationDelay = '3s';
    const ingredientsDelay = '750ms';
    final headers = <String, String>{};
    if (errorOnRecommendations) {
      headers['x-error-record-recommendation'] =
          'simulated recommendation service failure';
    }
    if (errorOnIngredients) {
      headers['x-error-get-ingredients'] =
          'simulated ingredient lookup failure';
    }
    if (slowRecommendations) {
      headers['x-delay-record-recommendation'] = recommendationDelay;
    }
    if (slowIngredients) {
      headers['x-delay-get-ingredients'] = ingredientsDelay;
    }
    return headers;
  }
}

class DebugSettingsNotifier extends Notifier<DebugSettings> {
  @override
  DebugSettings build() {
    _loadFromPrefs();
    return const DebugSettings();
  }

  /// Synchronously populates from prefs (best-effort). Callers who need
  /// guaranteed up-to-date state should await [reload].
  Future<void> _loadFromPrefs() async {
    state = await _readFromPrefs();
  }

  Future<DebugSettings> _readFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    return DebugSettings(
      backendUrlOverride: prefs.getString(DebugSettingsKeys.backendUrl),
      faroCollectorUrlOverride: prefs.getString(
        DebugSettingsKeys.faroCollectorUrl,
      ),
      errorOnRecommendations:
          prefs.getBool(DebugSettingsKeys.errorRecommendations) ?? false,
      errorOnIngredients:
          prefs.getBool(DebugSettingsKeys.errorIngredients) ?? false,
      slowRecommendations:
          prefs.getBool(DebugSettingsKeys.slowRecommendations) ?? false,
      slowIngredients:
          prefs.getBool(DebugSettingsKeys.slowIngredients) ?? false,
      useV2PizzaSchema:
          prefs.getBool(DebugSettingsKeys.useV2PizzaSchema) ?? false,
      skipAuthDepInTools:
          prefs.getBool(DebugSettingsKeys.skipAuthDepInTools) ?? false,
    );
  }

  /// Force a re-read from SharedPreferences. Useful in bootstrap where
  /// we want state to be guaranteed-loaded before the UI renders.
  Future<void> reload() async {
    state = await _readFromPrefs();
  }

  /// Persists both URL overrides atomically. Empty/whitespace values
  /// clear the corresponding override.
  ///
  /// Returns `true` if either URL override actually changed, so the
  /// caller can decide whether to show the restart banner.
  Future<bool> saveUrls({
    required String? backendUrl,
    required String? faroCollectorUrl,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    final normalizedBackend = _normalize(backendUrl);
    final normalizedFaro = _normalize(faroCollectorUrl);

    final prevBackend = state.backendUrlOverride;
    final prevFaro = state.faroCollectorUrlOverride;

    if (normalizedBackend != null) {
      await prefs.setString(DebugSettingsKeys.backendUrl, normalizedBackend);
    } else {
      await prefs.remove(DebugSettingsKeys.backendUrl);
    }

    if (normalizedFaro != null) {
      await prefs.setString(DebugSettingsKeys.faroCollectorUrl, normalizedFaro);
    } else {
      await prefs.remove(DebugSettingsKeys.faroCollectorUrl);
    }

    state = state.copyWith(
      backendUrlOverride: () => normalizedBackend,
      faroCollectorUrlOverride: () => normalizedFaro,
    );

    return prevBackend != normalizedBackend || prevFaro != normalizedFaro;
  }

  String? _normalize(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    return trimmed.replaceAll(RegExp(r'/$'), '');
  }

  Future<void> setErrorOnRecommendations(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(DebugSettingsKeys.errorRecommendations, value);
    state = state.copyWith(errorOnRecommendations: value);
  }

  Future<void> setErrorOnIngredients(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(DebugSettingsKeys.errorIngredients, value);
    state = state.copyWith(errorOnIngredients: value);
  }

  Future<void> setSlowRecommendations(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(DebugSettingsKeys.slowRecommendations, value);
    state = state.copyWith(slowRecommendations: value);
  }

  Future<void> setSlowIngredients(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(DebugSettingsKeys.slowIngredients, value);
    state = state.copyWith(slowIngredients: value);
  }

  Future<void> setUseV2PizzaSchema(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(DebugSettingsKeys.useV2PizzaSchema, value);
    state = state.copyWith(useV2PizzaSchema: value);
  }

  Future<void> setSkipAuthDepInTools(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(DebugSettingsKeys.skipAuthDepInTools, value);
    state = state.copyWith(skipAuthDepInTools: value);
  }

  Future<void> resetAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(DebugSettingsKeys.backendUrl);
    await prefs.remove(DebugSettingsKeys.faroCollectorUrl);
    await prefs.remove(DebugSettingsKeys.errorRecommendations);
    await prefs.remove(DebugSettingsKeys.errorIngredients);
    await prefs.remove(DebugSettingsKeys.slowRecommendations);
    await prefs.remove(DebugSettingsKeys.slowIngredients);
    await prefs.remove(DebugSettingsKeys.useV2PizzaSchema);
    await prefs.remove(DebugSettingsKeys.skipAuthDepInTools);
    state = const DebugSettings();
  }
}
