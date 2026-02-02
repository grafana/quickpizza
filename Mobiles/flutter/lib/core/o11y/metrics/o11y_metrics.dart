import 'package:faro/faro.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../loggers/o11y_logger.dart';

final o11yMetricsProvider = Provider<O11yMetrics>((ref) {
  return EmptyO11yMetrics(
    consoleO11yLogger: ref.watch(consoleO11yLoggerProvider),
  );
  // TODO: Uncomment this when Faro is ready to use with Metrics
  // return FaroO11yMetrics(faro: ref.watch(faroProvider));
});

abstract class O11yMetrics {
  void addMeasurement(String name, Map<String, dynamic> values);
}

class FaroO11yMetrics implements O11yMetrics {
  FaroO11yMetrics({required Faro faro}) : _faro = faro;

  final Faro _faro;

  @override
  void addMeasurement(String name, Map<String, dynamic> values) {
    _faro.pushMeasurement(values, name);
  }
}

class EmptyO11yMetrics implements O11yMetrics {
  EmptyO11yMetrics({required ConsoleO11yLogger consoleO11yLogger})
    : _consoleO11yLogger = consoleO11yLogger;

  final ConsoleO11yLogger _consoleO11yLogger;

  @override
  void addMeasurement(String name, Map<String, dynamic> values) {
    _consoleO11yLogger.debug('O11yMetrics: Adding measurement: $name, $values');
    // Do nothing
  }
}
