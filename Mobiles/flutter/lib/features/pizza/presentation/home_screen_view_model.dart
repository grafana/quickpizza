import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/o11y/loggers/o11y_logger.dart';
import '../domain/pizza_provider.dart';

class HomeScreenUiState extends Equatable {
  const HomeScreenUiState({required this.pizzaState});

  final PizzaState pizzaState;

  @override
  List<Object?> get props => [pizzaState];
}

class _HomeScreenViewModel extends Notifier<HomeScreenUiState> {
  // ---------------------------------------------------------------------------
  // Dependencies (initialized in build)
  // ---------------------------------------------------------------------------

  late O11yLogger _o11yLogger;

  @override
  HomeScreenUiState build() {
    // Initialize dependencies (watch to ensure we always have current instances)
    _o11yLogger = ref.watch(o11yLoggerProvider);

    // Watch state providers (triggers rebuild when these change)
    final pizzaState = ref.watch(pizzaStateProvider);

    _o11yLogger.debug('Home screen ViewModel initialized');

    return HomeScreenUiState(pizzaState: pizzaState);
  }
}

// =============================================================================
// Providers
// =============================================================================

final _homeScreenViewModelProvider =
    NotifierProvider<_HomeScreenViewModel, HomeScreenUiState>(
      _HomeScreenViewModel.new,
    );

final homeScreenUiStateProvider = Provider<HomeScreenUiState>((ref) {
  return ref.watch(_homeScreenViewModelProvider);
});
