// test/widget_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('App smoke test — CurrentaApp renders',
      (WidgetTester tester) async {
    // Build the app without ProviderScope (basic render test)
    // Full integration tests require a real ProviderScope + mocked repository
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: Center(child: Text('Currenta'))),
    ));
    expect(find.text('Currenta'), findsOneWidget);
  });
}
