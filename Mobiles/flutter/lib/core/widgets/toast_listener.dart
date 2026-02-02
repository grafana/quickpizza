import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'toast_service.dart';

/// A widget that listens for toast messages and displays them as SnackBars.
///
/// Wrap this around your app (or a section of your app) to enable toast
/// messages from anywhere via [ToastService].
///
/// Example:
/// ```dart
/// ToastListener(
///   child: MaterialApp(...),
/// )
/// ```
class ToastListener extends ConsumerWidget {
  const ToastListener({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen<ToastMessage?>(toastMessageProvider, (prev, next) {
      if (next != null) {
        _showSnackBar(context, next);
        // Clear the message after showing
        Future.microtask(() {
          ref.read(toastMessageProvider.notifier).clear();
        });
      }
    });

    return child;
  }

  void _showSnackBar(BuildContext context, ToastMessage message) {
    final backgroundColor = switch (message.type) {
      ToastType.error => Colors.red.shade700,
      ToastType.warning => Colors.orange.shade700,
      ToastType.success => Colors.green.shade700,
      ToastType.info => null, // Use default theme color
    };

    final icon = switch (message.type) {
      ToastType.error => Icons.error_outline,
      ToastType.warning => Icons.warning_amber_outlined,
      ToastType.success => Icons.check_circle_outline,
      ToastType.info => Icons.info_outline,
    };

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(child: Text(message.text)),
          ],
        ),
        backgroundColor: backgroundColor,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }
}
