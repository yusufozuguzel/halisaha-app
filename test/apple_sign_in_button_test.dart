import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halisaha_app/widgets/apple_sign_in_button.dart';

void main() {
  testWidgets(
    'iOS shows Apple entry point and invokes sign-in callback',
    (tester) async {
      var calls = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: AppleSignInButton(onPressed: () => calls++)),
        ),
      );
      expect(find.text('Apple ile Devam Et'), findsOneWidget);
      await tester.tap(find.text('Apple ile Devam Et'));
      expect(calls, 1);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );

  testWidgets(
    'native iOS entry point is hidden on Android and Windows',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppleSignInButton(
              onPressed: () => fail('Must not be invoked'),
            ),
          ),
        ),
      );
      expect(find.text('Apple ile Devam Et'), findsNothing);
    },
    variant: const TargetPlatformVariant({
      TargetPlatform.android,
      TargetPlatform.windows,
    }),
  );
}
