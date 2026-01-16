import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/o11y/errors/o11y_errors.dart';
import '../../../core/o11y/loggers/o11y_logger.dart';
import '../../../core/o11y/metrics/o11y_metrics.dart';
import '../models/rating.dart';

final ratingsRepositoryProvider = Provider((ref) {
  return RatingsRepository(
    apiClient: ref.watch(apiClientProvider),
    o11yLogger: ref.watch(o11yLoggerProvider),
    o11yMetrics: ref.watch(o11yMetricsProvider),
    o11yErrors: ref.watch(o11yErrorsProvider),
  );
});

class RatingsRepository {
  RatingsRepository({
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

  Future<bool> ratePizza(int pizzaId, int stars) async {
    try {
      final rating = Rating(id: 0, pizzaId: pizzaId, stars: stars);
      final response = await _apiClient.post(
        '/api/ratings',
        body: rating.toJson(),
        endpointName: 'ratePizza',
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        _o11yLogger.debug(
          'Pizza rated successfully',
          context: {'pizza_id': pizzaId.toString(), 'stars': stars.toString()},
        );
        _o11yMetrics.addMeasurement('pizza.rating', {
          'pizza_id': pizzaId,
          'stars': stars,
        });
        return true;
      } else if (response.statusCode == 401) {
        _o11yLogger.warning('Rating pizza requires authentication');
        throw Exception('You may need to be logged in');
      } else if (response.statusCode == 403) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        final error = json['error'] as String?;
        final errorMsg =
            error ?? 'You don\'t have permission to do this operation';
        _o11yErrors.reportError(
          type: 'API',
          error: errorMsg,
          context: {'endpoint': 'ratePizza', 'status_code': '403'},
        );
        throw Exception(errorMsg);
      } else {
        final errorMsg = 'Failed to rate pizza. Please try again.';
        _o11yErrors.reportError(
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
        _o11yErrors.reportError(
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
    try {
      final response = await _apiClient.get(
        '/api/ratings',
        endpointName: 'getRatings',
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        final ratings = json['ratings'] as List;
        final ratingsList = ratings
            .map((r) => Rating.fromJson(r as Map<String, dynamic>))
            .toList();
        _o11yLogger.debug(
          'Ratings fetched successfully',
          context: {'count': ratingsList.length.toString()},
        );
        return ratingsList;
      }
      return [];
    } catch (e, stackTrace) {
      _o11yErrors.reportError(
        type: 'API',
        error: 'Failed to get ratings: ${e.toString()}',
        stacktrace: stackTrace,
        context: {'endpoint': 'getRatings'},
      );
      return [];
    }
  }

  Future<bool> deleteRatings() async {
    try {
      final response = await _apiClient.delete(
        '/api/ratings',
        endpointName: 'deleteRatings',
      );

      if (response.statusCode == 200) {
        _o11yLogger.debug('Ratings deleted successfully');
        return true;
      } else if (response.statusCode == 401) {
        _o11yLogger.warning('Delete ratings requires authentication');
        throw Exception('You may need to be logged in');
      } else if (response.statusCode == 403) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        final error = json['error'] as String?;
        final errorMsg =
            error ?? 'You don\'t have permission to do this operation';
        _o11yErrors.reportError(
          type: 'API',
          error: errorMsg,
          context: {'endpoint': 'deleteRatings', 'status_code': '403'},
        );
        throw Exception(errorMsg);
      } else {
        final errorMsg = 'Failed to delete ratings. Please try again.';
        _o11yErrors.reportError(
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
        _o11yErrors.reportError(
          type: 'API',
          error: 'Error deleting ratings: ${e.toString()}',
          stacktrace: stackTrace,
          context: {'endpoint': 'deleteRatings'},
        );
      }
      rethrow;
    }
  }
}
