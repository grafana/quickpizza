import 'package:faro/faro.dart';
import 'package:flutter_mobile_o11y_demo/core/application_layer/o11y/faro/faro.dart';

class O11yErrors {
  O11yErrors() : _faro = faro;

  final Faro _faro;

  void reportError({
    required String type,
    required String error,
    StackTrace? stacktrace,
    Map<String, String>? context,
  }) {
    _faro.pushError(
      type: type,
      value: error,
      stacktrace: stacktrace,
      context: context,
    );
  }
}

final o11yErrors = O11yErrors();
