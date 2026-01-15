import 'package:faro/faro.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/about/ui/about_screen.dart';
import '../../features/auth/ui/login_screen.dart';
import '../../features/pizza/ui/home_screen.dart';
import '../../features/profile/ui/profile_screen.dart';
import '../../features/shell/ui/main_shell.dart';

/// Route paths as constants for type-safe navigation
abstract class AppRoutes {
  static const home = '/';
  static const about = '/about';
  static const login = '/login';
  static const profile = '/profile';
}

/// Navigator key for the root navigator
final _rootNavigatorKey = GlobalKey<NavigatorState>();

/// Navigator key for the shell (bottom nav) navigator
final _shellNavigatorKey = GlobalKey<NavigatorState>();

/// Provider for the GoRouter instance
final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: AppRoutes.home,
    observers: [FaroNavigationObserver()],
    routes: [
      // ShellRoute wraps the bottom navigation bar
      ShellRoute(
        navigatorKey: _shellNavigatorKey,
        builder: (_, _, child) {
          return MainShell(child: child);
        },
        routes: [
          GoRoute(
            path: AppRoutes.home,
            pageBuilder: (_, _) => const NoTransitionPage(child: HomeScreen()),
          ),
          GoRoute(
            path: AppRoutes.about,
            pageBuilder: (_, _) => const NoTransitionPage(child: AboutScreen()),
          ),
        ],
      ),
      // Routes outside the shell (full-screen, no bottom nav)
      GoRoute(
        path: AppRoutes.login,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (_, _) => const LoginScreen(),
      ),
      GoRoute(
        path: AppRoutes.profile,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (_, _) => const ProfileScreen(),
      ),
    ],
  );
});
