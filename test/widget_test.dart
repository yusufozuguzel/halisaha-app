// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'dart:async';
import 'package:flutter_test/flutter_test.dart';

import 'package:halisaha_app/widgets/delete_account_sheet.dart';

void main() {
  testWidgets('successful logout may dispose the sheet while deletion awaits', (
    tester,
  ) async {
    final pending = Completer<void>();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DeleteAccountSheet(
            requiresPassword: true,
            onDelete: (_) => pending.future,
          ),
        ),
      ),
    );
    await tester.enterText(find.byType(TextField), 'test password');
    await tester.tap(find.byType(ElevatedButton));
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    pending.complete();
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
  testWidgets('password reaches deletion unchanged and is cleared', (
    tester,
  ) async {
    String? received;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DeleteAccountSheet(
            requiresPassword: true,
            onDelete: (password) async {
              received = password;
            },
          ),
        ),
      ),
    );
    await tester.enterText(find.byType(TextField), '  test password  ');
    expect(
      tester.widget<TextField>(find.byType(TextField)).obscureText,
      isTrue,
    );
    await tester.tap(find.byType(ElevatedButton));
    await tester.pump();
    expect(received, '  test password  ');
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      isEmpty,
    );
  });

  testWidgets('social accounts do not get a password field', (tester) async {
    String? received;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DeleteAccountSheet(
            requiresPassword: false,
            onDelete: (password) async {
              received = password;
            },
          ),
        ),
      ),
    );
    expect(find.byType(TextField), findsNothing);
    await tester.tap(find.byType(ElevatedButton));
    await tester.pump();
    expect(received, '');
  });
}
