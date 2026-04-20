// Smoke test: verifies QuickPizzaApp mounts without throwing.
//
// This is deliberately minimal. A richer test would need to mock out the
// full provider tree (auth, pizza, Faro, network), which is out of scope
// for a demo app of this size.
//
// We override `runtimeConfigProvider` and warm it before pumping because
// bootstrap normally awaits its future before running the app; tests
// don't go through bootstrap, so without warming the provider stays in
// AsyncLoading and downstream consumers call `.requireValue` on it.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_mobile_o11y_demo/bootstrap.dart';
import 'package:flutter_mobile_o11y_demo/core/config/runtime_config.dart';

void main() {
  testWidgets('QuickPizzaApp mounts', (WidgetTester tester) async {
    final container = ProviderContainer(
      overrides: [
        runtimeConfigProvider.overrideWith(
          (ref) async => const RuntimeConfig(
            backendBaseUrl: 'http://localhost:3333',
            faroCollectorUrl: '',
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    // Warm the FutureProvider so `.requireValue` is safe on first frame.
    await container.read(runtimeConfigProvider.future);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const QuickPizzaApp(),
      ),
    );

    // Don't settle — downstream HTTP providers would attempt real network
    // calls. A single frame is enough to prove the app mounts.
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
