// This file is a testing entry point for AI-assisted testing via Flutter Driver.
// It's intentionally placed in lib/ for easy access, but uses flutter_driver from dev_dependencies.
// ignore_for_file: depend_on_referenced_packages
import 'package:flutter_driver/driver_extension.dart';

import 'bootstrap.dart';

void main() async {
  // Enable Flutter Driver extension for MCP/AI interaction
  enableFlutterDriverExtension();

  await bootstrap(
    const BootstrapConfig(appEnv: 'production', enableFlutterDriver: true),
  );
}
