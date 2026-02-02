import 'package:flutter/material.dart';

/// Centralized color constants for the QuickPizza app.
///
/// Usage:
/// ```dart
/// backgroundColor: AppColors.scaffoldBackground,
/// ```
class AppColors {
  AppColors._(); // Prevent instantiation

  /// Cream background color used for Scaffold backgrounds
  static const Color scaffoldBackground = Color(0xFFFFF5E6);

  /// White background for AppBars
  static const Color appBarBackground = Colors.white;

  /// Primary orange color for action buttons and highlights
  static const Color primaryAction = Colors.orange;
}
