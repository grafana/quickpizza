import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class ConfigService {
  static String get baseUrl {
    // First, check if BASE_URL is set in .env file
    final envBaseUrl = dotenv.env['BASE_URL'];
    if (envBaseUrl != null && envBaseUrl.isNotEmpty) {
      return envBaseUrl;
    }

    // If not set, determine based on platform
    if (kIsWeb) {
      // For web, use localhost
      return 'http://localhost:3333';
    }

    if (Platform.isAndroid) {
      // Android emulator uses 10.0.2.2 to access host's localhost
      // For physical devices, you need to set BASE_URL in .env with your machine's IP
      return 'http://10.0.2.2:3333';
    } else if (Platform.isIOS) {
      // iOS simulator can access localhost directly
      // For physical devices, you need to set BASE_URL in .env with your machine's IP
      return 'http://localhost:3333';
    }

    // Default fallback
    return 'http://localhost:3333';
  }

  static String get port {
    return dotenv.env['PORT'] ?? '3333';
  }

  /// Initialize the config service by loading .env file
  static Future<void> init() async {
    try {
      await dotenv.load(fileName: '.env');
    } catch (e) {
      // .env file is optional, so we just log if it's not found
      if (kDebugMode) {
        print('Warning: .env file not found. Using default configuration.');
      }
    }
  }
}
