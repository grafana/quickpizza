import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/o11y/events/o11y_events.dart';
import '../../../core/o11y/metrics/o11y_metrics.dart';
import '../models/rating.dart';
import 'ratings_repository.dart';

/// Provider for the list of user ratings
final ratingsProvider =
    AsyncNotifierProvider<RatingsNotifier, List<Rating>>(RatingsNotifier.new);

class RatingsNotifier extends AsyncNotifier<List<Rating>> {
  @override
  Future<List<Rating>> build() async {
    return [];
  }

  RatingsRepository get _ratingsRepository => ref.read(ratingsRepositoryProvider);
  O11yEvents get _o11yEvents => ref.read(o11yEventsProvider);
  O11yMetrics get _o11yMetrics => ref.read(o11yMetricsProvider);

  Future<void> loadRatings() async {
    state = const AsyncValue.loading();
    try {
      final ratings = await _ratingsRepository.getRatings();
      state = AsyncValue.data(ratings);
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
    }
  }

  Future<bool> ratePizza(int pizzaId, int stars, String type) async {
    _o11yEvents.startUserAction(
      'ratePizza',
      {
        'pizza_id': pizzaId.toString(),
        'stars': stars.toString(),
        'type': type,
      },
      triggerName: 'ratePizzaButtonClick',
    );

    _o11yEvents.trackEvent(
      'pizza_rated',
      context: {
        'pizza_id': pizzaId.toString(),
        'stars': stars.toString(),
        'rating_type': type,
      },
    );

    try {
      final success = await _ratingsRepository.ratePizza(pizzaId, stars);
      if (success) {
        _o11yMetrics.addMeasurement('pizza.rating', {
          'pizza_id': pizzaId,
          'stars': stars,
        });
        // Reload ratings after successful rate
        await loadRatings();
      }
      return success;
    } catch (e) {
      rethrow;
    }
  }

  Future<bool> deleteRatings() async {
    final currentRatings = state.value ?? [];
    _o11yEvents.startUserAction(
      'userDeleteRatings',
      {'count': currentRatings.length.toString()},
      triggerName: 'userDeleteRatingsButtonClick',
      importance: 'critical',
    );

    _o11yEvents.trackEvent(
      'ratings_deleted',
      context: {'count': currentRatings.length.toString()},
    );

    try {
      final success = await _ratingsRepository.deleteRatings();
      if (success) {
        state = const AsyncValue.data([]);
      }
      return success;
    } catch (e) {
      rethrow;
    }
  }

  void clear() {
    state = const AsyncValue.data([]);
  }
}
