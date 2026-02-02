import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../localization/app_localizations_provider.dart';
import '../router/app_router.dart';
import '../../features/auth/domain/auth_provider.dart';

// =============================================================================
// UI State
// =============================================================================

/// Represents the UI state for the QuickPizzaAppBar.
class QuickPizzaAppBarState extends Equatable {
  const QuickPizzaAppBarState({
    required this.isLoggedIn,
    required this.appName,
  });

  final bool isLoggedIn;
  final String appName;

  @override
  List<Object?> get props => [isLoggedIn, appName];
}

// =============================================================================
// Actions Interface
// =============================================================================

/// Defines the actions available on the QuickPizzaAppBar.
abstract interface class QuickPizzaAppBarActions {
  /// Navigates to the profile screen if logged in, otherwise to login.
  void navigateToProfile();
}

// =============================================================================
// ViewModel Implementation
// =============================================================================

/// ViewModel that manages the QuickPizzaAppBar state and actions.
class _QuickPizzaAppBarViewModel extends Notifier<QuickPizzaAppBarState>
    implements QuickPizzaAppBarActions {
  late GoRouter _router;

  @override
  QuickPizzaAppBarState build() {
    _router = ref.watch(appRouterProvider);

    final isLoggedIn = ref.watch(isLoggedInProvider);
    final l10n = ref.watch(appLocalizationsProvider);

    return QuickPizzaAppBarState(isLoggedIn: isLoggedIn, appName: l10n.appName);
  }

  @override
  void navigateToProfile() {
    if (state.isLoggedIn) {
      _router.push(AppRoutes.profile);
    } else {
      _router.push(AppRoutes.login);
    }
  }
}

// =============================================================================
// Providers
// =============================================================================

/// Private provider for the ViewModel implementation.
final _quickPizzaAppBarViewModelProvider =
    NotifierProvider<_QuickPizzaAppBarViewModel, QuickPizzaAppBarState>(
      _QuickPizzaAppBarViewModel.new,
    );

/// Provider for the QuickPizzaAppBar UI state.
final quickPizzaAppBarStateProvider = Provider<QuickPizzaAppBarState>((ref) {
  return ref.watch(_quickPizzaAppBarViewModelProvider);
});

/// Provider for QuickPizzaAppBar actions.
final quickPizzaAppBarActionsProvider = Provider<QuickPizzaAppBarActions>((
  ref,
) {
  return ref.read(_quickPizzaAppBarViewModelProvider.notifier);
});
