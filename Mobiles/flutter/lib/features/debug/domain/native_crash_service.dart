import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Invokes a real native crash on iOS / Android via a MethodChannel.
///
/// This is demo-only — it exists to exercise Faro's native crash reporting
/// pipeline (PLCrashReporter on iOS, `Thread.UncaughtExceptionHandler` +
/// `ApplicationExitInfo` on Android). A "real" crash can't be captured from
/// the same session it happens in: the app terminates before anything can be
/// flushed. Faro reads the persisted crash record on the next app launch and
/// sends it to the collector then.
///
/// Dart-level `exit(1)` is deliberately NOT used here — it's a clean process
/// exit, not a crash, and neither platform's native crash reporter records it.
class NativeCrashService {
  static const _channel = MethodChannel('com.grafana.quickpizza/debug/crash');

  /// Triggers a native crash with a custom message.
  ///   * iOS:     `fatalError(message)`                 → SIGTRAP / EXC_BREAKPOINT
  ///   * Android: `throw RuntimeException(message)`    → uncaught on main thread
  Future<void> crashWithMessage(String message) {
    return _channel.invokeMethod<void>('crashWithMessage', {
      'message': message,
    });
  }

  /// Triggers a native crash that simulates a real-world null-dereference bug.
  ///   * iOS:     force-unwrap of a nil Optional        → "Unexpectedly found nil…"
  ///   * Android: `!!` on a null reference              → KotlinNullPointerException
  Future<void> crashWithNullPointer() {
    return _channel.invokeMethod<void>('crashWithNullPointer');
  }
}

final nativeCrashServiceProvider = Provider<NativeCrashService>((ref) {
  return NativeCrashService();
});
