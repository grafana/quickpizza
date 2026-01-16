import 'package:equatable/equatable.dart';
import 'package:flutter_mobile_o11y_demo/core/localization/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_localizations_provider.dart';
import '../../../core/o11y/errors/o11y_errors.dart';
import '../../../core/o11y/loggers/o11y_logger.dart';
import '../../ratings/domain/ratings_provider.dart';
import '../domain/pizza_provider.dart';

// =============================================================================
// UI State
// =============================================================================

/// Represents the UI state for the HomeScreen.
/// This is a pure data class with no behavior.
///
/// Extends [Equatable] to enable value-based equality, which allows Riverpod
/// to skip unnecessary widget rebuilds when the state values haven't changed.
class HomeScreenUiState extends Equatable {
  const HomeScreenUiState({required this.pizzaState});

  final PizzaState pizzaState;

  @override
  List<Object?> get props => [pizzaState];
}

// =============================================================================
// Actions Interface
// =============================================================================

/// Defines the actions available on the HomeScreen.
/// This interface hides Riverpod implementation details from the UI layer.
abstract interface class HomeScreenActions {
  /// Rates the current pizza recommendation.
  Future<void> ratePizza(int stars, String type);
}

// =============================================================================
// ViewModel Implementation
// =============================================================================

/// Private ViewModel that implements both the Notifier contract and Actions interface.
/// This class manages the UI state and handles user actions for the HomeScreen.
class _HomeScreenViewModel extends Notifier<HomeScreenUiState>
    implements HomeScreenActions {
  // ---------------------------------------------------------------------------
  // Dependencies (initialized in build)
  // ---------------------------------------------------------------------------

  late PizzaStateNotifier _pizzaStateNotifier;
  late RatingsNotifier _ratingsNotifier;
  late O11yErrors _o11yErrors;
  late O11yLogger _o11yLogger;
  late AppLocalizations _l10n;

  @override
  HomeScreenUiState build() {
    // Initialize dependencies (watch to ensure we always have current instances)
    _pizzaStateNotifier = ref.watch(pizzaStateProvider.notifier);
    _ratingsNotifier = ref.watch(ratingsProvider.notifier);
    _o11yErrors = ref.watch(o11yErrorsProvider);
    _o11yLogger = ref.watch(o11yLoggerProvider);
    _l10n = ref.watch(appLocalizationsProvider);

    // Watch state providers (triggers rebuild when these change)
    final pizzaState = ref.watch(pizzaStateProvider);

    _o11yLogger.debug('Home screen ViewModel initialized');

    return HomeScreenUiState(pizzaState: pizzaState);
  }

  // ---------------------------------------------------------------------------
  // Actions Implementation
  // ---------------------------------------------------------------------------

  @override
  Future<void> ratePizza(int stars, String type) async {
    final pizzaState = ref.read(pizzaStateProvider);
    if (pizzaState.pizza == null) return;

    try {
      final success = await _ratingsNotifier.ratePizza(
        pizzaState.pizza!.pizza.id,
        stars,
        type,
      );

      if (success) {
        _pizzaStateNotifier.setRateResult(
          type == 'love'
              ? '❤️ ${_l10n.savedToFavorites}'
              : '👎 ${_l10n.gotItNextTime}',
        );
      } else {
        _pizzaStateNotifier.setRateResult(_l10n.pleaseLoginFirst);
      }
    } catch (e, stackTrace) {
      final errorStr = e.toString();
      final message = errorStr.startsWith('Exception: ')
          ? errorStr.substring(10)
          : errorStr;
      _pizzaStateNotifier.setRateResult(message);

      _o11yErrors.reportError(
        type: 'UI',
        error: 'Failed to rate pizza: $e',
        stacktrace: stackTrace,
        context: {
          'screen': 'home',
          'action': 'ratePizza',
          'pizza_id': pizzaState.pizza!.pizza.id.toString(),
        },
      );
    }
  }
}

// =============================================================================
// Providers
// =============================================================================

/// Private provider for the ViewModel implementation.
/// Not exposed directly - use the public providers below instead.
final _homeScreenViewModelProvider =
    NotifierProvider<_HomeScreenViewModel, HomeScreenUiState>(
      _HomeScreenViewModel.new,
    );

/// Provider for the HomeScreen UI state.
/// Use this to watch for state changes in the UI.
///
/// Example:
/// ```dart
/// final uiState = ref.watch(homeScreenUiStateProvider);
/// ```
final homeScreenUiStateProvider = Provider<HomeScreenUiState>((ref) {
  return ref.watch(_homeScreenViewModelProvider);
});

/// Provider for HomeScreen actions.
/// Use this to get the actions object for handling user interactions.
///
/// Example:
/// ```dart
/// final actions = ref.read(homeScreenActionsProvider);
/// actions.ratePizza(5, 'love');
/// ```
final homeScreenActionsProvider = Provider<HomeScreenActions>((ref) {
  return ref.read(_homeScreenViewModelProvider.notifier);
});
