import 'package:faro/faro.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../faro/faro.dart';

final o11yErrorsProvider = Provider<O11yErrors>((ref) {
  return FaroO11yErrors(faro: ref.watch(faroProvider));
});

abstract class O11yErrors {
  void reportError({
    required String type,
    required String error,
    StackTrace? stacktrace,
    Map<String, String>? context,
  });
}

class FaroO11yErrors implements O11yErrors {
  FaroO11yErrors({required Faro faro}) : _faro = faro;

  final Faro _faro;

  @override
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
