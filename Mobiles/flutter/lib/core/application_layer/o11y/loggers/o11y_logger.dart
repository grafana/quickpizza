import 'package:faro/faro.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final o11yLoggerProvider = Provider<O11yLogger>((ref) {
  return MultiO11yLogger(loggers: [ConsoleLoggerClient(), FaroLoggerClient()]);
});

abstract class O11yLogger {
  void debug(String message, {Map<String, String> context = const {}});
  void warning(String message, {Map<String, String> context = const {}});
  void error(
    String message, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, String> context = const {},
  });
}

class MultiO11yLogger implements O11yLogger {
  MultiO11yLogger({required List<O11yLogger> loggers}) : _loggers = loggers;

  final List<O11yLogger> _loggers;

  @override
  void debug(String message, {Map<String, String> context = const {}}) {
    for (final logger in _loggers) {
      logger.debug(message, context: context);
    }
  }

  @override
  void warning(String message, {Map<String, String> context = const {}}) {
    for (final logger in _loggers) {
      logger.warning(message, context: context);
    }
  }

  @override
  void error(
    String message, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, String> context = const {},
  }) {
    for (final logger in _loggers) {
      logger.error(
        message,
        error: error,
        stackTrace: stackTrace,
        context: context,
      );
    }
  }
}

class ConsoleLoggerClient implements O11yLogger {
  ConsoleLoggerClient();

  @override
  void debug(String message, {Map<String, String> context = const {}}) {
    // ignore: avoid_print
    print('[D]: $message, $context');
  }

  @override
  void warning(String message, {Map<String, String> context = const {}}) {
    // ignore: avoid_print
    print('[W]: $message, $context');
  }

  @override
  void error(
    String message, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, String> context = const {},
  }) {
    // ignore: avoid_print
    print(
      '[E]: $message, error: $error, stackTrace: $stackTrace, context: $context',
    );
  }
}

class FaroLoggerClient implements O11yLogger {
  FaroLoggerClient() : _faro = Faro();

  final Faro _faro;

  @override
  void debug(String message, {Map<String, String> context = const {}}) {
    _faro.pushLog(message, level: LogLevel.debug, context: context);
  }

  @override
  void warning(String message, {Map<String, String> context = const {}}) {
    _faro.pushLog(message, level: LogLevel.warn, context: context);
  }

  @override
  void error(
    String message, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, String> context = const {},
  }) {
    var allContext = <String, dynamic>{};
    if (error != null) {
      allContext = {...context, 'error': error.toString()};
    }
    if (stackTrace != null) {
      allContext = {...allContext, 'stackTrace': stackTrace.toString()};
    }
    _faro.pushLog(message, level: LogLevel.error, context: allContext);
  }
}
