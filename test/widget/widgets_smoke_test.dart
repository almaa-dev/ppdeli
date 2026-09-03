// Widget-level smoke tests that exercise common UI primitives used
// throughout the Pickles & Pies app without needing real Firebase / Maps.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Scaffold / AppBar', () {
    testWidgets('renders an AppBar with a title', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: AppBar(title: const Text('Welcome')),
            body: const Center(child: Text('Body content')),
          ),
        ),
      );

      expect(find.byType(AppBar), findsOneWidget);
      expect(find.text('Welcome'), findsOneWidget);
      expect(find.text('Body content'), findsOneWidget);
    });
  });

  group('Form validation', () {
    testWidgets('TextFormField reports errors', (tester) async {
      final formKey = GlobalKey<FormState>();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Form(
              key: formKey,
              child: TextFormField(
                validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
              ),
            ),
          ),
        ),
      );

      formKey.currentState!.validate();
      await tester.pump();

      expect(find.text('Required'), findsOneWidget);
    });

    testWidgets('TextFormField accepts valid input', (tester) async {
      final formKey = GlobalKey<FormState>();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Form(
              key: formKey,
              child: TextFormField(
                validator: (v) => (v == null || v.length < 3) ? 'Too short' : null,
              ),
            ),
          ),
        ),
      );

      await tester.enterText(find.byType(TextFormField), 'valid');
      final isValid = formKey.currentState!.validate();
      await tester.pump();

      expect(isValid, true);
      expect(find.text('Too short'), findsNothing);
    });
  });

  group('Lists', () {
    testWidgets('ListView renders all items', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ListView(
              children: const [
                ListTile(title: Text('Item 1')),
                ListTile(title: Text('Item 2')),
                ListTile(title: Text('Item 3')),
              ],
            ),
          ),
        ),
      );

      expect(find.text('Item 1'), findsOneWidget);
      expect(find.text('Item 2'), findsOneWidget);
      expect(find.text('Item 3'), findsOneWidget);
    });
  });
}