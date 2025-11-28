// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_mobile_o11y_demo/main.dart';

void main() {
  testWidgets('QuickPizza app loads', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const QuickPizzaApp());

    // Verify that the app title is present
    expect(find.text('QuickPizza'), findsWidgets);
    expect(find.text('Looking to break out of your pizza routine?'), findsOneWidget);
  });
}
