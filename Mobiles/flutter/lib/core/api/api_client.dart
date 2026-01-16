import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../config/config_service.dart';
import '../o11y/errors/o11y_errors.dart';
import '../o11y/loggers/o11y_logger.dart';
import '../o11y/metrics/o11y_metrics.dart';

final apiClientProvider = Provider((ref) {
  return ApiClient(
    configService: ref.watch(configServiceProvider),
    o11yLogger: ref.watch(o11yLoggerProvider),
    o11yMetrics: ref.watch(o11yMetricsProvider),
    o11yErrors: ref.watch(o11yErrorsProvider),
    httpClient: http.Client(),
  );
});

/// Base API client that handles HTTP requests with observability
class ApiClient {
  ApiClient({
    required ConfigService configService,
    required O11yLogger o11yLogger,
    required O11yMetrics o11yMetrics,
    required O11yErrors o11yErrors,
    required http.Client httpClient,
  }) : _configService = configService,
       _o11yLogger = o11yLogger,
       _o11yMetrics = o11yMetrics,
       _o11yErrors = o11yErrors,
       _httpClient = httpClient;

  static const _timeout = Duration(seconds: 30);

  final http.Client _httpClient;
  final ConfigService _configService;
  // ignore: unused_field
  final O11yLogger _o11yLogger;
  final O11yMetrics _o11yMetrics;
  final O11yErrors _o11yErrors;

  String get baseUrl => _configService.baseUrl;

  String? _userToken;

  void setUserToken(String? token) {
    _userToken = token;
  }

  String? get userToken => _userToken;

  bool get isAuthenticated => _userToken != null && _userToken!.isNotEmpty;

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    if (_userToken != null && _userToken!.isNotEmpty)
      'Authorization': 'Token $_userToken',
  };

  Future<http.Response> get(String endpoint, {String? endpointName}) async {
    final name = endpointName ?? endpoint;
    final stopwatch = Stopwatch()..start();

    try {
      final response = await _httpClient
          .get(Uri.parse('$baseUrl$endpoint'), headers: _headers)
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
    final name = endpointName ?? endpoint;
    final stopwatch = Stopwatch()..start();

    try {
      final headers = includeAuth
          ? _headers
          : {'Content-Type': 'application/json'};
      final response = await _httpClient
          .post(
            Uri.parse('$baseUrl$endpoint'),
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
    final name = endpointName ?? endpoint;
    final stopwatch = Stopwatch()..start();

    try {
      final response = await _httpClient
          .delete(Uri.parse('$baseUrl$endpoint'), headers: _headers)
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
