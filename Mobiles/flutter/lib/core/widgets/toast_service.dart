import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The type of toast message, used for styling.
enum ToastType { info, warning, error, success }

/// A toast message with text and type.
class ToastMessage extends Equatable {
  const ToastMessage(this.text, {this.type = ToastType.info});

  final String text;
  final ToastType type;

  @override
  List<Object?> get props => [text, type];
}

/// Notifier that manages the current toast message.
/// Uses the modern Riverpod 3.0 Notifier API instead of legacy StateProvider.
class ToastNotifier extends Notifier<ToastMessage?> {
  /// Tracks the last shown message to avoid duplicates.
  ToastMessage? _lastShownMessage;

  /// Timestamp of when the last message was shown.
  DateTime? _lastShownTime;

  /// Duration to consider messages as duplicates.
  static const _duplicateWindow = Duration(seconds: 2);

  @override
  ToastMessage? build() => null;

  /// Sets the current toast message.
  /// Ignores duplicate consecutive messages within the duplicate window.
  void show(ToastMessage message) {
    final now = DateTime.now();

    // Check if this is a duplicate message within the window
    if (_lastShownMessage == message &&
        _lastShownTime != null &&
        now.difference(_lastShownTime!) < _duplicateWindow) {
      // Ignore duplicate
      return;
    }

    _lastShownMessage = message;
    _lastShownTime = now;
    state = message;
  }

  /// Clears the current toast message.
  void clear() {
    state = null;
  }
}

/// Provider that holds the current toast message to display.
/// Set to null after the toast is shown.
final toastMessageProvider = NotifierProvider<ToastNotifier, ToastMessage?>(
  ToastNotifier.new,
);

/// Service for showing toast messages from anywhere in the app.
///
/// Usage:
/// ```dart
/// ref.read(toastServiceProvider).show('Hello!');
/// ref.read(toastServiceProvider).warning('Be careful!');
/// ref.read(toastServiceProvider).error('Something went wrong');
/// ```
class ToastService {
  ToastService(this._ref);

  final Ref _ref;

  /// Shows an info toast (default).
  void show(String message) {
    _ref.read(toastMessageProvider.notifier).show(ToastMessage(message));
  }

  /// Shows a warning toast (orange).
  void warning(String message) {
    _ref
        .read(toastMessageProvider.notifier)
        .show(ToastMessage(message, type: ToastType.warning));
  }

  /// Shows an error toast (red).
  void error(String message) {
    _ref
        .read(toastMessageProvider.notifier)
        .show(ToastMessage(message, type: ToastType.error));
  }

  /// Shows a success toast (green).
  void success(String message) {
    _ref
        .read(toastMessageProvider.notifier)
        .show(ToastMessage(message, type: ToastType.success));
  }
}

/// Provider for the ToastService.
final toastServiceProvider = Provider<ToastService>((ref) {
  return ToastService(ref);
});
