import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Provider for accessing the app's package info (version, build number, etc.)
final packageInfoProvider = FutureProvider<PackageInfo>((ref) async {
  return PackageInfo.fromPlatform();
});

/// Provider for accessing just the app version string (e.g., "1.0.0")
final appVersionProvider = Provider<String>((ref) {
  final packageInfoAsync = ref.watch(packageInfoProvider);
  return packageInfoAsync.when(
    data: (info) => info.version,
    loading: () => '...',
    error: (_, _) => 'unknown',
  );
});

/// Provider for accessing the full version string including build number (e.g., "1.0.0+1")
final appFullVersionProvider = Provider<String>((ref) {
  final packageInfoAsync = ref.watch(packageInfoProvider);
  return packageInfoAsync.when(
    data: (info) => '${info.version}+${info.buildNumber}',
    loading: () => '...',
    error: (_, _) => 'unknown',
  );
});
