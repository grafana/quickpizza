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
  @override
  PizzaState build() => const PizzaState();

  PizzaRepository get _pizzaRepository => ref.read(pizzaRepositoryProvider);
  O11yEvents get _o11yEvents => ref.read(o11yEventsProvider);
  O11yLogger get _o11yLogger => ref.read(o11yLoggerProvider);
  O11yMetrics get _o11yMetrics => ref.read(o11yMetricsProvider);

  Future<void> getPizza(Restrictions restrictions) async {
    _o11yEvents.startUserAction('getPizza', {
      'customized':
          (restrictions.maxCaloriesPerSlice != 1000 ||
                  restrictions.mustBeVegetarian ||
                  restrictions.excludedTools.isNotEmpty)
              .toString(),
      'vegetarian': restrictions.mustBeVegetarian.toString(),
      'max_calories': restrictions.maxCaloriesPerSlice.toString(),
      'min_toppings': restrictions.minNumberOfToppings.toString(),
      'max_toppings': restrictions.maxNumberOfToppings.toString(),
    }, triggerName: 'getPizzaButtonClick');

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
    } catch (e, _) {
      final errorStr = e.toString();
      final errorMessage = errorStr.startsWith('Exception: ')
          ? errorStr.substring(10)
          : errorStr;

      state = state.copyWith(isLoading: false, errorMessage: errorMessage);
    }
  }
}
