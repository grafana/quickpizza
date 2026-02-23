import 'package:flutter_mobile_o11y_demo/core/config/app_version_resolver.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppVersionResolver', () {
    const resolver = AppVersionResolver();

    test('returns base version when CI demo versioning is disabled', () {
      final result = resolver.resolveTelemetryAppVersion(
        baseVersion: '1.1.1',
        enableCiDemoVersioning: false,
      );

      expect(result, '1.1.1');
    });

    test('returns base version when base version is not semver', () {
      final result = resolver.resolveTelemetryAppVersion(
        baseVersion: 'dev-build',
        enableCiDemoVersioning: true,
      );

      expect(result, 'dev-build');
    });

    test('returns a stable result within the same UTC hour', () {
      final first = resolver.resolveTelemetryAppVersion(
        baseVersion: '1.1.1',
        enableCiDemoVersioning: true,
        nowUtc: DateTime.utc(2026, 2, 19, 13, 1, 0),
      );
      final second = resolver.resolveTelemetryAppVersion(
        baseVersion: '1.1.1',
        enableCiDemoVersioning: true,
        nowUtc: DateTime.utc(2026, 2, 19, 13, 59, 59),
      );

      expect(second, first);
    });

    test('returns only allowed base/patch variants', () {
      const allowed = {'1.1.1', '1.1.2', '1.1.3'};

      for (var hour = 0; hour < 24; hour++) {
        final result = resolver.resolveTelemetryAppVersion(
          baseVersion: '1.1.1',
          enableCiDemoVersioning: true,
          nowUtc: DateTime.utc(2026, 2, 19, hour, 0, 0),
        );

        expect(allowed.contains(result), isTrue, reason: 'hour=$hour');
      }
    });

    test('uses patch-only bumps from a .0 base', () {
      const allowed = {'1.1.0', '1.1.1', '1.1.2'};

      for (var hour = 0; hour < 24; hour++) {
        final result = resolver.resolveTelemetryAppVersion(
          baseVersion: '1.1.0',
          enableCiDemoVersioning: true,
          nowUtc: DateTime.utc(2026, 2, 19, hour, 0, 0),
        );

        expect(allowed.contains(result), isTrue, reason: 'hour=$hour');
      }
    });
  });

  group('appVersionResolverProvider', () {
    test('exposes AppVersionResolver via ProviderContainer', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final resolver = container.read(appVersionResolverProvider);

      expect(resolver, isA<AppVersionResolver>());
    });
  });
}
