// ignore_for_file: avoid_print

import 'package:faro/faro.dart';
import 'package:flutter_mobile_o11y_demo/core/application_layer/o11y/faro/faro.dart';

abstract class LoggerClient {
  void debug(String message, {required Map<String, String> context});

  void warning(String message, {required Map<String, String> context});

  void error(
    String message, {
    Object? error,
    StackTrace? stackTrace,
    required Map<String, String> context,
  });
}

class ConsoleLoggerClient implements LoggerClient {
  ConsoleLoggerClient();

  @override
  void debug(String message, {required Map<String, String> context}) {
    print('[D]: $message, $context');
  }

  @override
  void warning(String message, {required Map<String, String> context}) {
    print('[W]: $message, $context');
  }

  @override
  void error(
    String message, {
    Object? error,
    StackTrace? stackTrace,
    required Map<String, String> context,
  }) {
    print('[E]: $message, ${error ?? ''}');
  }
}

class FaroLoggerClient implements LoggerClient {
  FaroLoggerClient() : _faro = faro;

  final Faro _faro;

  @override
  void debug(String message, {required Map<String, String> context}) {
    _faro.pushLog(message, level: LogLevel.debug, context: context);
  }

  @override
  void warning(String message, {required Map<String, String> context}) {
    _faro.pushLog(message, level: LogLevel.warn, context: context);
  }

  @override
  void error(
    String message, {
    Object? error,
    StackTrace? stackTrace,
    required Map<String, String> context,
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
