import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/o11y/events/o11y_events.dart';
import '../../../core/o11y/loggers/o11y_logger.dart';
import '../../../core/o11y/metrics/o11y_metrics.dart';
import '../../auth/domain/auth_provider.dart';
import '../models/pizza.dart';
import '../models/restrictions.dart';
import 'pizza_repository.dart';

/// Provider for the current quote
final quoteProvider = FutureProvider.autoDispose<String>((ref) async {
  final repository = ref.watch(pizzaRepositoryProvider);
  return repository.getQuote();
});

/// Provider for available tools
/// Watches [isLoggedInProvider] to automatically refetch when auth state changes
final toolsProvider = FutureProvider.autoDispose<List<String>>((ref) async {
  // Watch auth state - this causes the provider to refetch when login/logout occurs
  ref.watch(isLoggedInProvider);

  final repository = ref.watch(pizzaRepositoryProvider);
  return repository.getTools();
});

/// Provider for the pizza recommendation state
final pizzaStateProvider = NotifierProvider<PizzaStateNotifier, PizzaState>(
  PizzaStateNotifier.new,
);

class PizzaState {
  const PizzaState({this.pizza, this.isLoading = false, this.errorMessage});

  final PizzaRecommendation? pizza;
  final bool isLoading;
  final String? errorMessage;

  PizzaState copyWith({
    PizzaRecommendation? pizza,
    bool? isLoading,
    String? errorMessage,
  }) {
    return PizzaState(
      pizza: pizza ?? this.pizza,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }
}

class PizzaStateNotifier extends Notifier<PizzaState> {
  late PizzaRepository _pizzaRepository;
  late O11yEvents _o11yEvents;
  late O11yLogger _o11yLogger;
  late O11yMetrics _o11yMetrics;

  @override
  PizzaState build() {
    _pizzaRepository = ref.watch(pizzaRepositoryProvider);
    _o11yEvents = ref.watch(o11yEventsProvider);
    _o11yLogger = ref.watch(o11yLoggerProvider);
    _o11yMetrics = ref.watch(o11yMetricsProvider);
    return PizzaState();
  }

  Future<void> getPizza(Restrictions restrictions) async {
    _o11yEvents.trackEvent(
      'pizza_requested',
      context: {'vegetarian': restrictions.mustBeVegetarian.toString()},
    );

    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      final pizza = await _pizzaRepository.getPizzaRecommendation(restrictions);

      if (pizza != null) {
        _o11yEvents.trackEvent(
          'pizza_received',
          context: {
            'pizza_id': pizza.pizza.id.toString(),
            'pizza_name': pizza.pizza.name,
          },
        );
        _o11yMetrics.addMeasurement('pizza.recommendation', {
          'pizza_id': pizza.pizza.id,
          'calories': pizza.calories ?? 0,
          'vegetarian': pizza.vegetarian == true ? 1 : 0,
        });
        state = state.copyWith(pizza: pizza, isLoading: false);
      } else {
        _o11yLogger.warning('Pizza recommendation returned null');
        state = state.copyWith(
          isLoading: false,
          errorMessage:
              'Failed to get pizza recommendation. Please log in and try again.',
        );
      }
    } catch (error, stackTrace) {
      _o11yLogger.error(
        'Failed to get pizza recommendation',
        error: error,
        stackTrace: stackTrace,
      );
      state = state.copyWith(isLoading: false, errorMessage: error.toString());
    }
  }
}
