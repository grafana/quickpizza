import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'config_service.dart';
import 'debug_settings.dart';

final backendUrlServiceProvider = Provider<BackendUrlService>((ref) {
  return BackendUrlService(ref.watch(configServiceProvider));
});

/// Thin wrapper around the backend base URL source.
///
/// Always prefer [getUrl] over reading [ConfigService.baseUrl]
/// directly, because it transparently applies any runtime override the
/// user saved from the debug Config screen.
class BackendUrlService {
  const BackendUrlService(this._configService);

  final ConfigService _configService;

  /// Returns the effective backend base URL to use for this session.
  ///
  /// Order of precedence:
  /// 1. Override in SharedPreferences (set via debug Config screen)
  /// 2. Build-time env / platform default (via [ConfigService.baseUrl])
  Future<String> getUrl() async {
    final prefs = await SharedPreferences.getInstance();
    final override = prefs.getString(DebugSettingsKeys.backendUrl);
    if (override != null && override.trim().isNotEmpty) {
      return override.trim();
    }
    return _configService.baseUrl;
  }
}
