import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../config/debug_settings.dart';
import '../config/runtime_config.dart';
import '../o11y/errors/o11y_errors.dart';
import '../o11y/metrics/o11y_metrics.dart';
import '../storage/token_storage.dart';

final apiClientProvider = Provider((ref) {
  // baseUrl is fixed for the session — captured from RuntimeConfig at bootstrap.
  // Bootstrap awaits runtimeConfigProvider.future before runApp, so
  // requireValue is always safe here.
  //
  // Error-injection headers are read live via a lambda, so toggles take
  // effect without needing to recreate the client.
  final runtimeConfig = ref.watch(runtimeConfigProvider).requireValue;
  final apiClient = ApiClient(
    baseUrl: runtimeConfig.backendBaseUrl,
    tokenStorage: ref.watch(tokenStorageProvider),
    o11yMetrics: ref.watch(o11yMetricsProvider),
    o11yErrors: ref.watch(o11yErrorsProvider),
    httpClient: http.Client(),
    errorHeadersProvider: () =>
        ref.read(debugSettingsProvider).errorInjectionHeaders,
  );
  ref.onDispose(apiClient.dispose);
  return apiClient;
});

/// Base API client that handles HTTP requests with observability
class ApiClient {
  ApiClient({
    required String baseUrl,
    required TokenStorage tokenStorage,
    required O11yMetrics o11yMetrics,
    required O11yErrors o11yErrors,
    required http.Client httpClient,
    Map<String, String> Function()? errorHeadersProvider,
  }) : _baseUrl = baseUrl,
       _tokenStorage = tokenStorage,
       _o11yMetrics = o11yMetrics,
       _o11yErrors = o11yErrors,
       _httpClient = httpClient,
       _errorHeadersProvider = errorHeadersProvider ?? _noHeaders {
    // Subscribe to session changes to keep cached token in sync
    _sessionSubscription = _tokenStorage.sessionChanges.listen((session) {
      _cachedToken = session.token;
      _hasLoadedInitialToken = true;
    });
  }

  static const _timeout = Duration(seconds: 10);
  static Map<String, String> _noHeaders() => const {};

  final http.Client _httpClient;
  final String _baseUrl;
  final TokenStorage _tokenStorage;
  final O11yMetrics _o11yMetrics;
  final O11yErrors _o11yErrors;
  final Map<String, String> Function() _errorHeadersProvider;

  StreamSubscription<StoredSession>? _sessionSubscription;
  String? _cachedToken;
  bool _hasLoadedInitialToken = false;

  String get baseUrl => _baseUrl;

  void dispose() {
    _sessionSubscription?.cancel();
  }

  /// Ensures the token is loaded, either from cache or storage.
  Future<void> _ensureTokenLoaded() async {
    if (!_hasLoadedInitialToken) {
      final session = await _tokenStorage.loadSession();
      _cachedToken = session.token;
      _hasLoadedInitialToken = true;
    }
  }

  String? get userToken => _cachedToken;

  bool get isAuthenticated => _cachedToken != null && _cachedToken!.isNotEmpty;

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    if (_cachedToken != null && _cachedToken!.isNotEmpty)
      'Authorization': 'Token $_cachedToken',
    ..._errorHeadersProvider(),
  };

  Future<http.Response> get(String endpoint, {String? endpointName}) async {
    await _ensureTokenLoaded();
    final name = endpointName ?? endpoint;
    final stopwatch = Stopwatch()..start();

    try {
      final response = await _httpClient
          .get(Uri.parse('$_baseUrl$endpoint'), headers: _headers)
          .timeout(_timeout);
      stopwatch.stop();

      _o11yMetrics.addMeasurement('api.request.duration', {
        'endpoint': name,
        'status_code': response.statusCode,
        'duration_ms': stopwatch.elapsedMilliseconds,
      });

      return response;
    } catch (e, stackTrace) {
      stopwatch.stop();
      _o11yErrors.reportError(
        type: 'API',
        error: 'GET $name failed: ${e.toString()}',
        stacktrace: stackTrace,
        context: {'endpoint': name},
      );
      rethrow;
    }
  }

  Future<http.Response> post(
    String endpoint, {
    Object? body,
    String? endpointName,
    bool includeAuth = true,
  }) async {
    if (includeAuth) await _ensureTokenLoaded();
    final name = endpointName ?? endpoint;
    final stopwatch = Stopwatch()..start();

    try {
      final headers = includeAuth
          ? _headers
          : {'Content-Type': 'application/json', ..._errorHeadersProvider()};
      final response = await _httpClient
          .post(
            Uri.parse('$_baseUrl$endpoint'),
            headers: headers,
            body: body != null ? jsonEncode(body) : null,
          )
          .timeout(_timeout);
      stopwatch.stop();

      _o11yMetrics.addMeasurement('api.request.duration', {
        'endpoint': name,
        'status_code': response.statusCode,
        'duration_ms': stopwatch.elapsedMilliseconds,
      });

      return response;
    } catch (e, stackTrace) {
      stopwatch.stop();
      _o11yErrors.reportError(
        type: 'API',
        error: 'POST $name failed: ${e.toString()}',
        stacktrace: stackTrace,
        context: {'endpoint': name},
      );
      rethrow;
    }
  }

  Future<http.Response> delete(String endpoint, {String? endpointName}) async {
    await _ensureTokenLoaded();
    final name = endpointName ?? endpoint;
    final stopwatch = Stopwatch()..start();

    try {
      final response = await _httpClient
          .delete(Uri.parse('$_baseUrl$endpoint'), headers: _headers)
          .timeout(_timeout);
      stopwatch.stop();

      _o11yMetrics.addMeasurement('api.request.duration', {
        'endpoint': name,
        'status_code': response.statusCode,
        'duration_ms': stopwatch.elapsedMilliseconds,
      });

      return response;
    } catch (e, stackTrace) {
      stopwatch.stop();
      _o11yErrors.reportError(
        type: 'API',
        error: 'DELETE $name failed: ${e.toString()}',
        stacktrace: stackTrace,
        context: {'endpoint': name},
      );
      rethrow;
    }
  }
}
