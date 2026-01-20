import 'dart:io';

import 'package:faro/faro.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/config/app_version_provider.dart';
import 'core/config/config_service.dart';
import 'core/localization/app_localizations.dart';
import 'core/o11y/faro/faro.dart';
import 'core/o11y/loggers/o11y_logger.dart';
import 'core/router/app_router.dart';
import 'core/utils/faro_utils.dart';
import 'features/auth/domain/auth_provider.dart';

/// Bootstrap configuration for the app.
class BootstrapConfig {
  const BootstrapConfig({
    required this.appEnv,
    this.enableFlutterDriver = false,
  });

  /// Environment name for Faro telemetry (e.g., 'production', 'development')
  final String appEnv;

  /// Whether Flutter Driver extension should be enabled (for AI/MCP testing)
  final bool enableFlutterDriver;
}

/// Bootstraps and runs the QuickPizza app with the given configuration.
///
/// This is the shared entry point used by both `main.dart` and `driver_main.dart`.
Future<void> bootstrap(BootstrapConfig config) async {
  WidgetsFlutterBinding.ensureInitialized();

  // Create ProviderContainer first - this is Riverpod's root
  // and allows us to access providers before runApp()
  final container = ProviderContainer();

  // Access the logger via Riverpod
  final logger = container.read(o11yLoggerProvider);
  final driverSuffix = config.enableFlutterDriver
      ? ' (with Flutter Driver)'
      : '';
  logger.debug('App initialization started$driverSuffix');

  // Restore auth session if user was previously logged in
  await container.read(authStateProvider.notifier).restoreSession();

  // Get app version from package info provider (warms up the provider for later use)
  final packageInfo = await container.read(packageInfoProvider.future);
  final appVersion = packageInfo.version;

  logger.debug('App version: $appVersion');

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
      appVersion: appVersion,
      appEnv: config.appEnv,
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

/// The main QuickPizza application widget.
class QuickPizzaApp extends ConsumerWidget {
  const QuickPizzaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      title: 'QuickPizza',
      debugShowCheckedModeBanner: false,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.red,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      routerConfig: router,
    );
  }
}
