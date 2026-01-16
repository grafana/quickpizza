import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/o11y/errors/o11y_errors.dart';
import '../../../core/o11y/loggers/o11y_logger.dart';

final authRepositoryProvider = Provider((ref) {
  return AuthRepository(
    apiClient: ref.watch(apiClientProvider),
    o11yLogger: ref.watch(o11yLoggerProvider),
    o11yErrors: ref.watch(o11yErrorsProvider),
  );
});

class AuthRepository {
  AuthRepository({
    required ApiClient apiClient,
    required O11yLogger o11yLogger,
    required O11yErrors o11yErrors,
  })  : _apiClient = apiClient,
        _o11yLogger = o11yLogger,
        _o11yErrors = o11yErrors;

  final ApiClient _apiClient;
  final O11yLogger _o11yLogger;
  final O11yErrors _o11yErrors;

  bool get isAuthenticated => _apiClient.isAuthenticated;

  Future<bool> login(String username, String password) async {
    try {
      final response = await _apiClient.post(
        '/api/users/token/login',
        body: {'username': username, 'password': password},
        endpointName: 'login',
        includeAuth: false,
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        final token = json['token'] as String?;
        if (token != null) {
          _apiClient.setUserToken(token);
          _o11yLogger.debug(
            'Login successful',
            context: {'username': username},
          );
          return true;
        }
      } else {
        _o11yLogger.warning(
          'Login failed',
          context: {
            'username': username,
            'status_code': response.statusCode.toString(),
          },
        );
      }
      return false;
    } catch (e, stackTrace) {
      _o11yErrors.reportError(
        type: 'API',
        error: 'Failed to login: ${e.toString()}',
        stacktrace: stackTrace,
        context: {'endpoint': 'login', 'username': username},
      );
      return false;
    }
  }

  void logout() {
    _apiClient.setUserToken(null);
    _o11yLogger.debug('User logged out');
  }
}
