import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:halisaha_app/core/services/account_deletion.dart';
import 'package:halisaha_app/core/services/firebase_account_deletion.dart';
import 'package:halisaha_app/core/services/safety_api.dart';

// Local characterization only. All credentials and HTTP responses are fixtures;
// no Firebase SDK initialization, real identity or network connection is used.
void main() {
  test('pending deletion readiness permits deleting a newly switched account',
      () async {
    var currentUid = 'alice';
    final readinessStarted = Completer<void>();
    final readinessResponse = Completer<http.Response>();
    final requests = <String>[];
    final deletedPrincipals = <String>[];
    final api = SafetyApi(
      projectId: 'demo-local-security-audit',
      appCheckToken: () async => null,
      // Mirrors production's per-call currentUser token lookup. These strings
      // are deliberately invalid synthetic credentials, never sent externally.
      token: () async => 'fixture-$currentUid',
      client: MockClient((request) async {
        final principal = request.headers['Authorization']!
            .replaceFirst('Bearer fixture-', '');
        requests.add('${request.url.path}:$principal');
        expect(jsonDecode(request.body), {'data': <String, dynamic>{}});
        if (request.url.path == '/prepareAccountDeletion') {
          readinessStarted.complete();
          return readinessResponse.future;
        }
        if (request.url.path == '/requestAccountDeletion') {
          deletedPrincipals.add(principal);
          return http.Response('{"result":{"accepted":true}}', 200);
        }
        fail('Unexpected endpoint');
      }),
    );
    final operation = AccountDeletion(
      backend: FirebaseAccountDeletion(api: api, currentUid: () => currentUid),
      currentUid: () => currentUid,
    ).run(
      reauthenticate: () async => true,
      revokeAppleConsent: () async => fail('Not an Apple account'),
      hasApple: false,
    );
    await readinessStarted.future;
    // User dismisses the sheet and changes accounts during readiness I/O.
    currentUid = 'bob';
    readinessResponse.complete(
      http.Response('{"result":{"ready":true}}', 200),
    );
    await expectLater(operation, throwsA(isA<DeletionUnavailable>()));
    expect(requests, [
      '/prepareAccountDeletion:alice',
    ]);
    expect(deletedPrincipals, isEmpty);
  });
}
