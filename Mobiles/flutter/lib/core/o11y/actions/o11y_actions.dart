import 'package:faro/faro.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../faro/faro.dart';

final o11yActionsProvider = Provider<O11yActions>((ref) {
  return FaroO11yActions(faro: ref.watch(faroProvider));
});

/// Abstraction for tracking user actions — high-level user interactions
/// that group related telemetry (HTTP requests, events, logs, errors)
/// under a single correlated context.
///
/// Only one action can be active at a time. Starting a new action while
/// one is already active is a no-op. Actions end automatically when the
/// related activity (HTTP responses, navigation) settles.
abstract class O11yActions {
  /// Starts a user action that groups all subsequent telemetry under
  /// the given [name] until the action's lifecycle completes.
  ///
  /// [attributes] are optional key-value pairs attached to the action.
  /// [isCritical] marks the action as high-importance for prioritized
  /// monitoring.
  void startUserAction(
    String name, {
    Map<String, String>? attributes,
    bool isCritical = false,
  });
}

class FaroO11yActions implements O11yActions {
  FaroO11yActions({required Faro faro}) : _faro = faro;

  final Faro _faro;

  @override
  void startUserAction(
    String name, {
    Map<String, String>? attributes,
    bool isCritical = false,
  }) {
    _faro.startUserAction(
      name,
      attributes: attributes,
      options: isCritical
          ? const StartUserActionOptions(
              importance: UserActionConstants.importanceCritical,
            )
          : null,
    );
  }
}
