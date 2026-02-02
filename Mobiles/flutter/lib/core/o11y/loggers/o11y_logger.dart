import 'dart:developer' as developer;

import 'package:faro/faro.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../faro/faro.dart';

final consoleO11yLoggerProvider = Provider((ref) {
  return ConsoleO11yLogger();
});

final faroO11yLoggerProvider = Provider((ref) {
  return FaroO11yLogger(faro: ref.watch(faroProvider));
});

final o11yLoggerProvider = Provider<O11yLogger>((ref) {
  return MultiO11yLogger(
    loggers: [
      ref.watch(consoleO11yLoggerProvider),
      ref.watch(faroO11yLoggerProvider),
    ],
  );
});

abstract class O11yLogger {
  void debug(String message, {Map<String, String>? context});
  void warning(String message, {Map<String, String>? context});
  void error(
    String message, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, String>? context,
  });
}

class MultiO11yLogger implements O11yLogger {
  MultiO11yLogger({required List<O11yLogger> loggers}) : _loggers = loggers;

  final List<O11yLogger> _loggers;

  @override
  void debug(String message, {Map<String, String>? context}) {
    for (final logger in _loggers) {
      logger.debug(message, context: context);
    }
  }

  @override
  void warning(String message, {Map<String, String>? context}) {
    for (final logger in _loggers) {
      logger.warning(message, context: context);
    }
  }

  @override
  void error(
    String message, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, String>? context,
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

class ConsoleO11yLogger implements O11yLogger {
  static const _logNameDebug = 'PizzaDemo:D';
  static const _logNameWarning = 'PizzaDemo:W';
  static const _logNameError = 'PizzaDemo:E';

  String _formatContext(Map<String, String>? context) {
    if (context == null || context.isEmpty) return '';
    return ' | $context';
  }

  @override
  void debug(String message, {Map<String, String>? context}) {
    developer.log(
      '$message${_formatContext(context)}',
      name: _logNameDebug,
      level: 500,
    );
  }

  @override
  void warning(String message, {Map<String, String>? context}) {
    developer.log(
      '$message${_formatContext(context)}',
      name: _logNameWarning,
      level: 900,
    );
  }

  @override
  void error(
    String message, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, String>? context,
  }) {
    developer.log(
      '$message${_formatContext(context)}',
      name: _logNameError,
      level: 1000,
      error: error,
      stackTrace: stackTrace,
    );
  }
}

class FaroO11yLogger implements O11yLogger {
  FaroO11yLogger({required Faro faro}) : _faro = faro;

  final Faro _faro;

  @override
  void debug(String message, {Map<String, String>? context}) {
    _faro.pushLog(message, level: LogLevel.debug, context: context);
  }

  @override
  void warning(String message, {Map<String, String>? context}) {
    _faro.pushLog(message, level: LogLevel.warn, context: context);
  }

  @override
  void error(
    String message, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, String>? context,
  }) {
    var allContext = <String, dynamic>{};
    if (context != null) {
      allContext = {...context};
    }
    if (error != null) {
      allContext = {...allContext, 'error': error.toString()};
    }
    if (stackTrace != null) {
      allContext = {...allContext, 'stackTrace': stackTrace.toString()};
    }
    _faro.pushLog(message, level: LogLevel.error, context: allContext);
  }
}
