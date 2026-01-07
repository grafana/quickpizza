import 'dart:io';
import 'package:flutter/foundation.dart';

class ConfigService {
  static String get baseUrl {
    // Check if BASE_URL is set via build-time config
    const baseUrl = String.fromEnvironment('BASE_URL');
    if (baseUrl.isNotEmpty) {
      return baseUrl;
    }

    // If not set, determine based on platform
    if (kIsWeb) {
      // For web, use localhost
      return 'http://localhost:$port';
    }

    if (Platform.isAndroid) {
      // Android emulator uses 10.0.2.2 to access host's localhost
      // For physical devices, you need to set BASE_URL in config.json with your machine's IP
      return 'http://10.0.2.2:$port';
    } else if (Platform.isIOS) {
      // iOS simulator can access localhost directly
      // For physical devices, you need to set BASE_URL in config.json with your machine's IP
      return 'http://localhost:$port';
    }

    // Default fallback
    return 'http://localhost:$port';
  }

  static String get port =>
      const String.fromEnvironment('PORT', defaultValue: '3333');

  /// Faro collector URL for observability.
  /// Throws [StateError] if not configured, as Faro is required for this demo app.
  static String get faroCollectorUrl {
    const url = String.fromEnvironment('FARO_COLLECTOR_URL');
    if (url.isEmpty) {
      throw StateError(
        '\n'
        '╔══════════════════════════════════════════════════════════════════╗\n'
        '║  FARO_COLLECTOR_URL is not configured!                           ║\n'
        '║                                                                  ║\n'
        '║  This demo app requires Faro for observability.                  ║\n'
        '║                                                                  ║\n'
        '║  To fix:                                                         ║\n'
        '║  1. Copy config.json.example to config.json                      ║\n'
        '║  2. Set your FARO_COLLECTOR_URL in config.json                   ║\n'
        '║  3. Rebuild the app                                              ║\n'
        '╚══════════════════════════════════════════════════════════════════╝\n',
      );
    }
    return url;
  }
}
