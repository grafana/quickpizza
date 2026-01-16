import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/o11y/errors/o11y_errors.dart';
import '../../../core/o11y/loggers/o11y_logger.dart';
import '../../../core/o11y/metrics/o11y_metrics.dart';
import '../models/pizza.dart';
import '../models/restrictions.dart';

final pizzaRepositoryProvider = Provider((ref) {
  return PizzaRepository(
    apiClient: ref.watch(apiClientProvider),
    o11yLogger: ref.watch(o11yLoggerProvider),
    o11yMetrics: ref.watch(o11yMetricsProvider),
    o11yErrors: ref.watch(o11yErrorsProvider),
  );
});

class PizzaRepository {
  PizzaRepository({
    required ApiClient apiClient,
    required O11yLogger o11yLogger,
    required O11yMetrics o11yMetrics,
    required O11yErrors o11yErrors,
  })  : _apiClient = apiClient,
        _o11yLogger = o11yLogger,
        _o11yMetrics = o11yMetrics,
        _o11yErrors = o11yErrors;

  final ApiClient _apiClient;
  final O11yLogger _o11yLogger;
  final O11yMetrics _o11yMetrics;
  final O11yErrors _o11yErrors;

  Future<String> getQuote() async {
    try {
      final response = await _apiClient.get(
        '/api/quotes',
        endpointName: 'getQuote',
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        final quotes = json['quotes'] as List;
        if (quotes.isNotEmpty) {
          _o11yLogger.debug('Quote fetched successfully');
          return quotes[0] as String;
        }
      } else {
        _o11yLogger.warning(
          'Failed to fetch quote',
          context: {'status_code': response.statusCode.toString()},
        );
      }
      return '';
    } catch (e, stackTrace) {
      _o11yErrors.reportError(
        type: 'API',
        error: 'Failed to get quote: ${e.toString()}',
        stacktrace: stackTrace,
        context: {'endpoint': 'getQuote'},
      );
      return '';
    }
  }

  Future<List<String>> getTools() async {
    try {
      final response = await _apiClient.get(
        '/api/tools',
        endpointName: 'getTools',
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        final tools = json['tools'] as List;
        final toolsList = tools.map((t) => t as String).toList();
        _o11yLogger.debug(
          'Tools fetched successfully',
          context: {'count': toolsList.length.toString()},
        );
        return toolsList;
      } else if (response.statusCode == 401) {
        _o11yLogger.debug('Tools fetch requires authentication');
      }
      return [];
    } catch (e, stackTrace) {
      _o11yErrors.reportError(
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
    try {
      final response = await _apiClient.post(
        '/api/pizza',
        body: restrictions.toJson(),
        endpointName: 'getPizzaRecommendation',
      );

      _o11yMetrics.addMeasurement('api.request.pizza', {
        'status_code': response.statusCode,
        'pizza.vegetarian': restrictions.mustBeVegetarian ? 1 : 0,
        'pizza.max_calories': restrictions.maxCaloriesPerSlice,
      });

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        final pizza = PizzaRecommendation.fromJson(json);
        _o11yLogger.debug(
          'Pizza recommendation fetched successfully',
          context: {
            'pizza_id': pizza.pizza.id.toString(),
            'pizza_name': pizza.pizza.name,
          },
        );
        return pizza;
      } else if (response.statusCode == 401) {
        _o11yLogger.warning('Pizza recommendation requires authentication');
        return null;
      } else if (response.statusCode == 403) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        final error = json['error'] as String?;
        final errorMsg = error ?? 'Operation not permitted';
        _o11yErrors.reportError(
          type: 'API',
          error: errorMsg,
          context: {
            'endpoint': 'getPizzaRecommendation',
            'status_code': '403',
          },
        );
        throw Exception(errorMsg);
      } else {
        _o11yLogger.warning(
          'Unexpected status code for pizza recommendation',
          context: {'status_code': response.statusCode.toString()},
        );
        return null;
      }
    } catch (e, stackTrace) {
      if (e is Exception) {
        _o11yErrors.reportError(
          type: 'API',
          error: 'Failed to get pizza recommendation: ${e.toString()}',
          stacktrace: stackTrace,
          context: {'endpoint': 'getPizzaRecommendation'},
        );
      }
      rethrow;
    }
  }
}
