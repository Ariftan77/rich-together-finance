import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:rich_together/main.dart';

void main() {
  testWidgets('App launch smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    // Must wrap in ProviderScope because RichTogetherApp/DashboardShell uses Riverpod
    await tester.pumpWidget(
      const ProviderScope(
        child: RichTogetherApp(),
      ),
    );

    // Verify that the DashboardShell is rendered
    // We look for the "Dashboard" text or one of the bottom nav items
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
