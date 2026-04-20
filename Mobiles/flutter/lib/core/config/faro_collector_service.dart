import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'config_service.dart';
import 'debug_settings.dart';

final faroCollectorServiceProvider = Provider<FaroCollectorService>((ref) {
  return const FaroCollectorService();
});

/// Thin wrapper around the Faro collector URL source.
///
/// Always prefer [getUrl] over reading [ConfigService.faroCollectorUrl]
/// directly, because it transparently applies any runtime override the
/// user saved from the debug Config screen.
class FaroCollectorService {
  const FaroCollectorService();

  /// Returns the effective collector URL to use for this session.
  ///
  /// Order of precedence:
  /// 1. Override in SharedPreferences (set via debug Config screen)
  /// 2. Build-time env (`FARO_COLLECTOR_URL`)
  Future<String> getUrl() async {
    final prefs = await SharedPreferences.getInstance();
    final override = prefs.getString(DebugSettingsKeys.faroCollectorUrl);
    if (override != null && override.trim().isNotEmpty) {
      return override.trim();
    }
    return ConfigService.faroCollectorUrl;
  }
}
