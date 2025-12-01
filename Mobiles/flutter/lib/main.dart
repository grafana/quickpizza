import 'package:flutter/material.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'services/api_service.dart';
import 'services/config_service.dart';
import 'screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize config service (loads .env file)
  await ConfigService.init();

  // Debug: Print Sentry configuration
  debugPrint('=== Sentry Configuration ===');
  debugPrint('Sentry DSN: ${ConfigService.sentryDsn}');
  debugPrint('Sentry Enabled: ${ConfigService.isSentryEnabled}');
  debugPrint('============================');

  // Initialize Sentry for error tracking
  if (ConfigService.isSentryEnabled) {
    await SentryFlutter.init((options) {
      options.dsn = ConfigService.sentryDsn;
      // Set environment (e.g., 'development', 'staging', 'production')
      options.environment = const String.fromEnvironment(
        'SENTRY_ENVIRONMENT',
        defaultValue: 'development',
      );
      // Enable performance monitoring
      options.tracesSampleRate = 1.0;
      // Enable profiling (requires tracing to be enabled)
      options.profilesSampleRate = 1.0;
      // Capture failed HTTP requests
      options.enableAutoPerformanceTracing = true;
      // Add release info for better error grouping
      options.release = '1.0.0+1';
      // Enable debug mode in development
      options.debug = true;
    }, appRunner: () => runApp(const QuickPizzaApp()));

    debugPrint('Sentry initialized successfully!');
  } else {
    // Run without Sentry if DSN is not configured
    debugPrint('Sentry is DISABLED - DSN not configured');
    runApp(const QuickPizzaApp());
  }
}

class QuickPizzaApp extends StatelessWidget {
  const QuickPizzaApp({super.key});

  @override
  Widget build(BuildContext context) {
    final apiService = ApiService();

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
      home: HomeScreen(apiService: apiService),
    );
  }
}
