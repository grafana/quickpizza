import 'package:flutter_driver/driver_extension.dart';

import 'bootstrap.dart';

void main() async {
  // Enable Flutter Driver extension for MCP/AI interaction
  enableFlutterDriverExtension();

  await bootstrap(
    const BootstrapConfig(appEnv: 'production', enableFlutterDriver: true),
  );
}
