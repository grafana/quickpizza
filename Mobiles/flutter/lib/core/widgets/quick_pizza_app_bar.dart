import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'quick_pizza_app_bar_view_model.dart';

/// A self-contained app bar with the QuickPizza branding and profile button.
///
/// This widget manages its own state and navigation logic via Riverpod.
///
/// Example:
/// ```dart
/// Scaffold(
///   appBar: const QuickPizzaAppBar(),
///   body: ...,
/// )
/// ```
class QuickPizzaAppBar extends ConsumerWidget implements PreferredSizeWidget {
  const QuickPizzaAppBar({super.key});

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(quickPizzaAppBarStateProvider);

    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      title: Row(
        children: [
          Icon(Icons.local_pizza, color: Colors.red.shade600, size: 28),
          const SizedBox(width: 8),
          Text(
            state.appName,
            style: TextStyle(
              color: Colors.red.shade600,
              fontWeight: FontWeight.bold,
              fontSize: 20,
            ),
          ),
        ],
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 8),
          child: GestureDetector(
            onTap: () =>
                ref.read(quickPizzaAppBarActionsProvider).navigateToProfile(),
            child: CircleAvatar(
              radius: 18,
              backgroundColor: state.isLoggedIn
                  ? Colors.orange
                  : Colors.grey.shade300,
              child: Icon(
                state.isLoggedIn ? Icons.person : Icons.person_outline,
                color: state.isLoggedIn ? Colors.white : Colors.grey.shade600,
                size: 20,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
