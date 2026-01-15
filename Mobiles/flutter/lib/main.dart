import 'dart:io';

import 'package:faro/faro.dart';
import 'package:flutter/material.dart';
import 'package:flutter_mobile_o11y_demo/core/o11y/faro/faro.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/config/config_service.dart';
import 'core/o11y/loggers/o11y_logger.dart';
import 'core/utils/faro_utils.dart';
import 'features/shell/ui/main_shell.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Create ProviderContainer first - this is Riverpod's root
  // and allows us to access providers before runApp()
  final container = ProviderContainer();

  // Access the logger via Riverpod
  final logger = container.read(o11yLoggerProvider);
  logger.debug('App initialization started');

  // Get collector URL from build-time config
  final collectorUrl = ConfigService.faroCollectorUrl;
  final apiKey = extractTokenFromCollectorUrl(collectorUrl);

  // Access Faro instance from the container
  final faro = container.read(faroProvider);

  HttpOverrides.global = FaroHttpOverrides(HttpOverrides.current);
  faro.transports.add(
    OfflineTransport(maxCacheDuration: const Duration(days: 3)),
  );

  faro.runApp(
    optionsConfiguration: FaroConfig(
      appName: 'QuickPizza_Flutter',
      appVersion: '1.0.0',
      appEnv: 'production',
      apiKey: apiKey,
      collectorUrl: collectorUrl,
      cpuUsageVitals: true,
      memoryUsageVitals: true,
      anrTracking: true,
      refreshRateVitals: true,
      fetchVitalsInterval: const Duration(seconds: 30),
      enableCrashReporting: true,
    ),
    appRunner: () {
      runApp(
        // Used by Riverpod to provide providers to the app
        UncontrolledProviderScope(
          container: container,
          child: DefaultAssetBundle(
            bundle: FaroAssetBundle(),
            child: const FaroUserInteractionWidget(child: QuickPizzaApp()),
          ),
        ),
      );
    },
  );
}

class QuickPizzaApp extends StatelessWidget {
  const QuickPizzaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'QuickPizza',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.red,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      navigatorObservers: [FaroNavigationObserver()],
      home: const MainShell(),
    );
  }
}
