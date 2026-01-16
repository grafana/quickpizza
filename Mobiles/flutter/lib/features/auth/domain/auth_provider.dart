import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/o11y/events/o11y_events.dart';
import '../../../core/o11y/loggers/o11y_logger.dart';
import 'auth_repository.dart';

/// Provider that exposes authentication state
final authStateProvider = NotifierProvider<AuthStateNotifier, AuthState>(
  AuthStateNotifier.new,
);

/// Convenience provider to check if user is logged in
final isLoggedInProvider = Provider<bool>((ref) {
  return ref.watch(authStateProvider).isLoggedIn;
});

class AuthState {
  const AuthState({
    this.isLoggedIn = false,
    this.username,
    this.isLoading = false,
    this.errorMessage,
  });

  final bool isLoggedIn;
  final String? username;
  final bool isLoading;
  final String? errorMessage;

  AuthState copyWith({
    bool? isLoggedIn,
    String? username,
    bool? isLoading,
    String? errorMessage,
  }) {
    return AuthState(
      isLoggedIn: isLoggedIn ?? this.isLoggedIn,
      username: username ?? this.username,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }
}

class AuthStateNotifier extends Notifier<AuthState> {
  @override
  AuthState build() => const AuthState();

  AuthRepository get _authRepository => ref.read(authRepositoryProvider);
  O11yEvents get _o11yEvents => ref.read(o11yEventsProvider);
  O11yLogger get _o11yLogger => ref.read(o11yLoggerProvider);

  Future<bool> login(String username, String password) async {
    _o11yEvents.trackStartEvent('login_attempt', 'user_login');

    state = state.copyWith(isLoading: true, errorMessage: null);

    final success = await _authRepository.login(username, password);

    if (success) {
      _o11yEvents.trackEndEvent(
        'login_attempt',
        'user_login',
        context: {'success': 'true', 'username': username},
      );
      _o11yEvents.setUser(
        id: username,
        name: username,
        email: '$username@quickpizza.com',
      );
      state = state.copyWith(
        isLoggedIn: true,
        username: username,
        isLoading: false,
      );
      return true;
    } else {
      _o11yEvents.trackEndEvent(
        'login_attempt',
        'user_login',
        context: {'success': 'false', 'username': username},
      );
      _o11yLogger.warning('Login failed', context: {'username': username});
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Login failed. Please check your credentials.',
      );
      return false;
    }
  }

  void logout() {
    final username = state.username;
    _o11yEvents.trackEvent(
      'user_logged_out',
      context: {'username': username ?? ''},
    );
    _authRepository.logout();
    state = const AuthState();
  }
}
