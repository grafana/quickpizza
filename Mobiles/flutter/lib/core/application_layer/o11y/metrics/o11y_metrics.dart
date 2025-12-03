import 'package:faro/faro.dart';
import 'package:flutter_mobile_o11y_demo/core/application_layer/o11y/faro/faro.dart';

class O11yMetrics {
  O11yMetrics() : _faro = faro;

  final Faro _faro;

  void addMeasurement(String name, Map<String, dynamic> values) {
    _faro.pushMeasurement(values, name);
  }
}

final o11yMetrics = O11yMetrics();
