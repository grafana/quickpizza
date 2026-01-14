import 'dart:io';

import 'package:faro/faro.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/application_layer/o11y/loggers/o11y_logger.dart';
import 'services/api_service.dart';
import 'services/config_service.dart';
import 'screens/main_shell.dart';
import 'utils/faro_utils.dart';

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

  // Initialize Faro instance first
  final faro = Faro();

  // Set HttpOverrides AFTER Faro instance is created to ensure HTTP tracing works
  // This must be done before any HTTP calls are made
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

class QuickPizzaApp extends ConsumerWidget {
  const QuickPizzaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final apiService = ref.watch(apiServiceProvider);

    // Note: User must login via LoginScreen to get a valid token.
    // Some APIs (quotes, config) work without auth, but others (ratings, pizza, tools) require authentication.

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
      home: MainShell(apiService: apiService),
    );
  }
}
