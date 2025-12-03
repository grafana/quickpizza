import 'dart:async';

import 'package:faro/faro.dart';
import 'package:flutter_mobile_o11y_demo/core/application_layer/o11y/faro/faro.dart';

class O11yTraces {
  O11yTraces() : _faro = faro;

  final Faro _faro;

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

  Span? getActiveSpan() {
    return _faro.getActiveSpan();
  }
}

final o11yTraces = O11yTraces();
