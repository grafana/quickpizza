import 'package:flutter_riverpod/flutter_riverpod.dart';

final appVersionResolverProvider = Provider<AppVersionResolver>((ref) {
  return const AppVersionResolver();
});

class AppVersionResolver {
  const AppVersionResolver();

  String resolveTelemetryAppVersion({
    required String baseVersion,
    required bool enableCiDemoVersioning,
    DateTime? nowUtc,
  }) {
    if (!enableCiDemoVersioning) {
      return baseVersion;
    }

    final match = RegExp(r'^(\d+)\.(\d+)\.(\d+)$').firstMatch(baseVersion);
    if (match == null) {
      return baseVersion;
    }

    final major = int.parse(match.group(1)!);
    final minor = int.parse(match.group(2)!);
    final patch = int.parse(match.group(3)!);

    // Keep the same variant for all launches in the same UTC hour.
    final now = (nowUtc ?? DateTime.now()).toUtc();
    final hourBucket =
        '${now.year.toString().padLeft(4, '0')}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}${now.hour.toString().padLeft(2, '0')}';

    final variant = _stableHash('$baseVersion|$hourBucket') % 3;
    if (variant == 0) {
      return '$major.$minor.$patch';
    }
    if (variant == 1) {
      return '$major.$minor.${patch + 1}';
    }
    return '$major.$minor.${patch + 2}';
  }

  int _stableHash(String input) {
    var hash = 5381;
    for (final codeUnit in input.codeUnits) {
      hash = ((hash << 5) + hash) ^ codeUnit;
      hash &= 0x7fffffff;
    }
    return hash;
  }
}
