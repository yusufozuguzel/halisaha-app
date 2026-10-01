import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halisaha_app/core/services/login_identifier.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test(
    'email login bypasses lookup and preserves the exact password',
    () async {
      final calls = <List<String>>[];
      final service = LoginIdentifier(
        client: MockClient((_) async => throw StateError('No lookup expected')),
        signIn: (email, password) async => calls.add([email, password]),
      );
      await service.signIn(' user@example.invalid ', ' password with spaces ');
      expect(calls, [
        ['user@example.invalid', ' password with spaces '],
      ]);
    },
  );

  test(
    'username verifies password on the fixed server then signs in natively',
    () async {
      final calls = <List<String>>[];
      final service = LoginIdentifier(
        projectId: 'demo-depar-review',
        client: MockClient((request) async {
          expect(
            request.url.toString(),
            'https://europe-west1-demo-depar-review.cloudfunctions.net/verifyUsernamePassword',
          );
          expect(jsonDecode(request.body), {
            'data': {'username': 'player', 'password': ' exact password '},
          });
          return http.Response(
            jsonEncode({
              'result': {'email': 'verified@example.invalid'},
            }),
            200,
          );
        }),
        signIn: (email, password) async => calls.add([email, password]),
      );
      await service.signIn(' player ', ' exact password ');
      expect(calls, [
        ['verified@example.invalid', ' exact password '],
      ]);
    },
  );

  test(
    'lookup failure, malformed data and throttling never start a session or expose server details',
    () async {
      for (final response in [
        http.Response(
          '{"error":{"status":"UNAUTHENTICATED","message":"secret profile"}}',
          401,
        ),
        http.Response('{"error":{"status":"RESOURCE_EXHAUSTED"}}', 429),
        http.Response('<html>service unavailable</html>', 503),
        http.Response('{"result":{"email":null}}', 200),
      ]) {
        final service = LoginIdentifier(
          projectId: 'demo-depar-review',
          client: MockClient((_) async => response),
          signIn: (_, _) async => fail('Must not sign in'),
        );
        await expectLater(
          service.signIn('player', 'test password'),
          throwsA(
            isA<LoginIdentifierException>().having(
              (e) => e.message,
              'message',
              isNot(contains('secret profile')),
            ),
          ),
        );
      }
    },
  );

  test(
    'username reset neither receives nor sends an email from the client',
    () async {
      final service = LoginIdentifier(
        projectId: 'demo-depar-review',
        client: MockClient((request) async {
          expect(request.url.path, '/resetUsernamePassword');
          expect(jsonDecode(request.body), {
            'data': {'username': 'player'},
          });
          return http.Response('{"result":{"accepted":true}}', 200);
        }),
        resetEmail: (_) async => fail('Server handles reset'),
      );
      await service.resetPassword(' player ');
    },
  );

  test(
    'direct email reset hides nonexistent accounts but preserves network failures',
    () async {
      for (final code in ['user-not-found', 'user-disabled']) {
        await LoginIdentifier(
          resetEmail: (_) async => throw FirebaseAuthException(code: code),
        ).resetPassword('unknown@example.invalid');
      }
      await expectLater(
        LoginIdentifier(
          resetEmail: (_) async =>
              throw FirebaseAuthException(code: 'network-request-failed'),
        ).resetPassword('unknown@example.invalid'),
        throwsA(isA<FirebaseAuthException>()),
      );
    },
  );

  test('blank identifier fails without sending credentials', () async {
    final service = LoginIdentifier(
      client: MockClient((_) async => fail('No request expected')),
    );
    await expectLater(
      service.signIn('   ', 'test password'),
      throwsA(isA<LoginIdentifierException>()),
    );
    await expectLater(
      service.resetPassword(''),
      throwsA(isA<LoginIdentifierException>()),
    );
  });
}
