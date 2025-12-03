import 'package:flutter_mobile_o11y_demo/core/application_layer/o11y/loggers/logger_client.dart';

class O11yLogger {
  O11yLogger({List<LoggerClient>? clients})
    : _clients = clients ?? [ConsoleLoggerClient(), FaroLoggerClient()];

  final List<LoggerClient> _clients;

  void debug(String message, {Map<String, String> context = const {}}) {
    for (final client in _clients) {
      client.debug(message, context: context);
    }
  }

  void warning(String message, {Map<String, String> context = const {}}) {
    for (final client in _clients) {
      client.warning(message, context: context);
    }
  }

  void error(
    String message, {
    DateTime? time,
    Object? error,
    StackTrace? stackTrace,
    Map<String, String> context = const {},
  }) {
    for (final client in _clients) {
      client.error(
        message,
        error: error,
        stackTrace: stackTrace,
        context: context,
      );
    }
  }
}

final o11yLogger = O11yLogger();
