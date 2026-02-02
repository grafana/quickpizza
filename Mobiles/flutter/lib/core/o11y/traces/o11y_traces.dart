import 'dart:async';

import 'package:faro/faro.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../faro/faro.dart';

final o11yTracesProvider = Provider<O11yTraces>((ref) {
  return FaroO11yTraces(faro: ref.watch(faroProvider));
});

abstract class O11yTraces {
  FutureOr<T> startSpan<T>(
    String name,
    FutureOr<T> Function(Span) body, {
    Map<String, String> attributes = const {},
    Span? parentSpan,
  });

  Span startSpanManual(
    String name, {
    Map<String, String> attributes = const {},
    Span? parentSpan,
  });

  Span? getActiveSpan();
}

class FaroO11yTraces implements O11yTraces {
  FaroO11yTraces({required Faro faro}) : _faro = faro;

  final Faro _faro;

  @override
  FutureOr<T> startSpan<T>(
    String name,
    FutureOr<T> Function(Span) body, {
    Map<String, String> attributes = const {},
    Span? parentSpan,
  }) async {
    return _faro.startSpan(
      name,
      body,
      attributes: attributes,
      parentSpan: parentSpan,
    );
  }

  @override
  Span startSpanManual(
    String name, {
    Map<String, String> attributes = const {},
    Span? parentSpan,
  }) {
    return _faro.startSpanManual(
      name,
      attributes: attributes,
      parentSpan: parentSpan,
    );
  }

  @override
  Span? getActiveSpan() {
    return _faro.getActiveSpan();
  }
}
