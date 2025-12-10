import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/application_layer/o11y/errors/o11y_errors.dart';
import '../core/application_layer/o11y/metrics/o11y_metrics.dart';
import '../core/application_layer/o11y/loggers/o11y_logger.dart';
import '../models/pizza.dart';
import '../models/restrictions.dart';
import '../models/rating.dart';
import 'config_service.dart';

class ApiService {
  // Get baseUrl from ConfigService which handles env variables and platform detection
  String get baseUrl => ConfigService.baseUrl;

  String? _userToken;

  void setUserToken(String? token) {
    _userToken = token;
  }

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    if (_userToken != null && _userToken!.isNotEmpty)
      'Authorization': 'Token $_userToken',
  };

  Future<String> getQuote() async {
    final stopwatch = Stopwatch()..start();
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/quotes'),
        headers: _headers,
      );
      stopwatch.stop();

      o11yMetrics.addMeasurement('api.request.duration', {
        'endpoint': 'getQuote',
        'status_code': response.statusCode,
        'duration_ms': stopwatch.elapsedMilliseconds,
      });

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        final quotes = json['quotes'] as List;
        if (quotes.isNotEmpty) {
          o11yLogger.debug('Quote fetched successfully', context: {});
          return quotes[0] as String;
        }
      } else {
        o11yLogger.warning(
          'Failed to fetch quote',
          context: {'status_code': response.statusCode.toString()},
        );
      }
      return '';
    } catch (e, stackTrace) {
      o11yErrors.reportError(
        type: 'API',
        error: 'Failed to get quote: ${e.toString()}',
        stacktrace: stackTrace,
        context: {'endpoint': 'getQuote'},
      );
      return '';
    }
  }

  Future<List<String>> getTools() async {
    final stopwatch = Stopwatch()..start();
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/tools'),
        headers: _headers,
      );
      stopwatch.stop();

      o11yMetrics.addMeasurement('api.request.duration', {
        'endpoint': 'getTools',
        'status_code': response.statusCode,
        'duration_ms': stopwatch.elapsedMilliseconds,
      });

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        final tools = json['tools'] as List;
        final toolsList = tools.map((t) => t as String).toList();
        o11yLogger.debug(
          'Tools fetched successfully',
          context: {'count': toolsList.length.toString()},
        );
        return toolsList;
      } else if (response.statusCode == 401) {
        o11yLogger.debug('Tools fetch requires authentication', context: {});
      }
      // 401 means authentication required - return empty list
      // User can still use the app, they just won't see tools in advanced options
      return [];
    } catch (e, stackTrace) {
      o11yErrors.reportError(
        type: 'API',
        error: 'Failed to get tools: ${e.toString()}',
        stacktrace: stackTrace,
        context: {'endpoint': 'getTools'},
      );
      return [];
    }
  }

  Future<PizzaRecommendation?> getPizzaRecommendation(
    Restrictions restrictions,
  ) async {
    final stopwatch = Stopwatch()..start();
    try {
      final url = '$baseUrl/api/pizza';
      final body = jsonEncode(restrictions.toJson());

      final response = await http.post(
        Uri.parse(url),
        headers: _headers,
        body: body,
      );
      stopwatch.stop();

      o11yMetrics.addMeasurement('api.request.duration', {
        'endpoint': 'getPizzaRecommendation',
        'status_code': response.statusCode,
        'duration_ms': stopwatch.elapsedMilliseconds,
        'pizza.vegetarian': restrictions.mustBeVegetarian ? 1 : 0,
        'pizza.max_calories': restrictions.maxCaloriesPerSlice,
      });

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        final pizza = PizzaRecommendation.fromJson(json);
        o11yLogger.debug(
          'Pizza recommendation fetched successfully',
          context: {
            'pizza_id': pizza.pizza.id.toString(),
            'pizza_name': pizza.pizza.name,
          },
        );
        return pizza;
      } else if (response.statusCode == 401) {
        o11yLogger.warning(
          'Pizza recommendation requires authentication',
          context: {},
        );
        return null;
      } else if (response.statusCode == 403) {
        // 403 Forbidden - user doesn't have permission
        try {
          final json = jsonDecode(response.body) as Map<String, dynamic>;
          final error = json['error'] as String?;
          final errorMsg = error ?? 'Operation not permitted';
          o11yErrors.reportError(
            type: 'API',
            error: errorMsg,
            context: {
              'endpoint': 'getPizzaRecommendation',
              'status_code': '403',
            },
          );
          throw Exception(errorMsg);
        } catch (e) {
          if (e is Exception) rethrow;
          throw Exception('Operation not permitted');
        }
      } else {
        o11yLogger.warning(
          'Unexpected status code for pizza recommendation',
          context: {'status_code': response.statusCode.toString()},
        );
        return null;
      }
    } catch (e, stackTrace) {
      if (e is Exception) {
        o11yErrors.reportError(
          type: 'API',
          error: 'Failed to get pizza recommendation: ${e.toString()}',
          stacktrace: stackTrace,
          context: {'endpoint': 'getPizzaRecommendation'},
        );
      }
      rethrow;
    }
  }

  Future<bool> ratePizza(int pizzaId, int stars) async {
    final stopwatch = Stopwatch()..start();
    try {
      final rating = Rating(id: 0, pizzaId: pizzaId, stars: stars);
      final response = await http.post(
        Uri.parse('$baseUrl/api/ratings'),
        headers: _headers,
        body: jsonEncode(rating.toJson()),
      );
      stopwatch.stop();

      o11yMetrics.addMeasurement('api.request.duration', {
        'endpoint': 'ratePizza',
        'status_code': response.statusCode,
        'duration_ms': stopwatch.elapsedMilliseconds,
        'pizza.id': pizzaId,
        'rating.stars': stars,
      });

      if (response.statusCode == 201 || response.statusCode == 200) {
        o11yLogger.debug(
          'Pizza rated successfully',
          context: {'pizza_id': pizzaId.toString(), 'stars': stars.toString()},
        );
        return true;
      } else if (response.statusCode == 401) {
        o11yLogger.warning('Rating pizza requires authentication', context: {});
        throw Exception('You may need to be logged in');
      } else if (response.statusCode == 403) {
        // 403 Forbidden - user doesn't have permission
        try {
          final json = jsonDecode(response.body) as Map<String, dynamic>;
          final error = json['error'] as String?;
          final errorMsg =
              error ?? 'You don\'t have permission to do this operation';
          o11yErrors.reportError(
            type: 'API',
            error: errorMsg,
            context: {'endpoint': 'ratePizza', 'status_code': '403'},
          );
          throw Exception(errorMsg);
        } catch (e) {
          if (e is Exception) rethrow;
          throw Exception('You don\'t have permission to do this operation');
        }
      } else {
        final errorMsg = 'Failed to rate pizza. Please try again.';
        o11yErrors.reportError(
          type: 'API',
          error: errorMsg,
          context: {
            'endpoint': 'ratePizza',
            'status_code': response.statusCode.toString(),
          },
        );
        throw Exception(errorMsg);
      }
    } catch (e, stackTrace) {
      if (e is Exception) {
        o11yErrors.reportError(
          type: 'API',
          error: 'Error rating pizza: ${e.toString()}',
          stacktrace: stackTrace,
          context: {'endpoint': 'ratePizza', 'pizza_id': pizzaId.toString()},
        );
      }
      rethrow;
    }
  }

  Future<List<Rating>> getRatings() async {
    final stopwatch = Stopwatch()..start();
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/ratings'),
        headers: _headers,
      );
      stopwatch.stop();

      o11yMetrics.addMeasurement('api.request.duration', {
        'endpoint': 'getRatings',
        'status_code': response.statusCode,
        'duration_ms': stopwatch.elapsedMilliseconds,
      });

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        final ratings = json['ratings'] as List;
        final ratingsList = ratings
            .map((r) => Rating.fromJson(r as Map<String, dynamic>))
            .toList();
        o11yLogger.debug(
          'Ratings fetched successfully',
          context: {'count': ratingsList.length.toString()},
        );
        return ratingsList;
      }
      return [];
    } catch (e, stackTrace) {
      o11yErrors.reportError(
        type: 'API',
        error: 'Failed to get ratings: ${e.toString()}',
        stacktrace: stackTrace,
        context: {'endpoint': 'getRatings'},
      );
      return [];
    }
  }

  Future<bool> deleteRatings() async {
    final stopwatch = Stopwatch()..start();
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/api/ratings'),
        headers: _headers,
      );
      stopwatch.stop();

      o11yMetrics.addMeasurement('api.request.duration', {
        'endpoint': 'deleteRatings',
        'status_code': response.statusCode,
        'duration_ms': stopwatch.elapsedMilliseconds,
      });

      if (response.statusCode == 200) {
        o11yLogger.debug('Ratings deleted successfully', context: {});
        return true;
      } else if (response.statusCode == 401) {
        o11yLogger.warning(
          'Delete ratings requires authentication',
          context: {},
        );
        throw Exception('You may need to be logged in');
      } else if (response.statusCode == 403) {
        try {
          final json = jsonDecode(response.body) as Map<String, dynamic>;
          final error = json['error'] as String?;
          final errorMsg =
              error ?? 'You don\'t have permission to do this operation';
          o11yErrors.reportError(
            type: 'API',
            error: errorMsg,
            context: {'endpoint': 'deleteRatings', 'status_code': '403'},
          );
          throw Exception(errorMsg);
        } catch (e) {
          if (e is Exception) rethrow;
          throw Exception('You don\'t have permission to do this operation');
        }
      } else {
        final errorMsg = 'Failed to delete ratings. Please try again.';
        o11yErrors.reportError(
          type: 'API',
          error: errorMsg,
          context: {
            'endpoint': 'deleteRatings',
            'status_code': response.statusCode.toString(),
          },
        );
        throw Exception(errorMsg);
      }
    } catch (e, stackTrace) {
      if (e is Exception) {
        o11yErrors.reportError(
          type: 'API',
          error: 'Error deleting ratings: ${e.toString()}',
          stacktrace: stackTrace,
          context: {'endpoint': 'deleteRatings'},
        );
      }
      rethrow;
    }
  }

  Future<bool> login(String username, String password) async {
    final stopwatch = Stopwatch()..start();
    try {
      // For mobile apps, we don't use set_cookie=true to avoid CSRF token requirements
      // The token will be returned in the JSON response and stored in memory
      final response = await http.post(
        Uri.parse('$baseUrl/api/users/token/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'username': username, 'password': password}),
      );
      stopwatch.stop();

      o11yMetrics.addMeasurement('api.request.duration', {
        'endpoint': 'login',
        'status_code': response.statusCode,
        'duration_ms': stopwatch.elapsedMilliseconds,
      });

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        final token = json['token'] as String?;
        if (token != null) {
          _userToken = token;
          o11yLogger.debug('Login successful', context: {'username': username});
          return true;
        }
      } else {
        o11yLogger.warning(
          'Login failed',
          context: {
            'username': username,
            'status_code': response.statusCode.toString(),
          },
        );
      }
      return false;
    } catch (e, stackTrace) {
      o11yErrors.reportError(
        type: 'API',
        error: 'Failed to login: ${e.toString()}',
        stacktrace: stackTrace,
        context: {'endpoint': 'login', 'username': username},
      );
      return false;
    }
  }
}
