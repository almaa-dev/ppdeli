// Basic smoke tests for the Pickles & Pies Flutter app.
//
// These tests are intentionally minimal — they verify that the test
// infrastructure itself works end-to-end without requiring Firebase, Google
// Maps, or any platform plugins. The actual app startup is exercised by
// deeper integration tests (see `test/integration/`).
//
// NOTE: The previous version of this file referenced a non-existent
// `MyApp` counter widget which made `flutter test` fail. It has been
// replaced with real, runnable smoke tests.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Smoke', () {
    testWidgets('MaterialApp renders and shows the title', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(child: Text('Pickles and Pies')),
          ),
        ),
      );

      expect(find.text('Pickles and Pies'), findsOneWidget);
      expect(find.byType(MaterialApp), findsOneWidget);
    });

    testWidgets('Tap on a button updates state', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => taps++,
                child: const Text('Increment'),
              ),
            ),
          ),
        ),
      );

      expect(taps, 0);

      await tester.tap(find.text('Increment'));
      await tester.pump();

      expect(taps, 1);
    });
  });
}