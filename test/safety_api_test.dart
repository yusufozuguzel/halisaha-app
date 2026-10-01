import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:halisaha_app/core/services/safety_api.dart';
import 'package:halisaha_app/core/services/content_reports.dart';
import 'package:halisaha_app/core/services/firebase_account_deletion.dart';

void main() {
  test(
    'report sends only content fields, using refreshed identity in header',
    () async {
      var refreshed = 0;
      final api = SafetyApi(
        projectId: 'demo-depar-review',
        token: () async {
          refreshed++;
          return 'test-only-token';
        },
        client: MockClient((request) async {
          expect(
            request.url.host,
            'europe-west1-demo-depar-review.cloudfunctions.net',
          );
          expect(request.url.path, '/submitContentReport');
          expect(request.headers['Authorization'], 'Bearer test-only-token');
          expect(jsonDecode(request.body), {
            'data': {'type': 'user', 'targetId': 'target', 'reason': 'spam'},
          });
          return http.Response('{"result":{"recorded":true}}', 200);
        }),
      );
      await ContentReports(api: api).submit(
        type: ReportTarget.user,
        targetId: 'target',
        reason: ReportReason.spam,
      );
      expect(refreshed, 1);
    },
  );
  test(
    'deletion never sends a client-selected UID, and requires explicit acceptance',
    () async {
      final paths = <String>[];
      final api = SafetyApi(
        projectId: 'demo-depar-review',
        token: () async => 'test-only-token',
        client: MockClient((request) async {
          paths.add(request.url.path);
          expect(jsonDecode(request.body), {'data': {}});
          return http.Response(
            request.url.path == '/prepareAccountDeletion'
                ? '{"result":{"ready":true}}'
                : '{"result":{"accepted":true}}',
            200,
          );
        }),
      );
      final backend = FirebaseAccountDeletion(api: api);
      await backend.prepareDeletion();
      await backend.deleteCurrentAccount();
      expect(paths, ['/prepareAccountDeletion', '/requestAccountDeletion']);
    },
  );
  test(
    'missing deployment, malformed response and server rejection never succeed',
    () async {
      for (final response in [
        http.Response('not deployed', 404),
        http.Response('{"result":null}', 200),
        http.Response('{"error":{"status":"UNAVAILABLE"}}', 503),
      ]) {
        final api = SafetyApi(
          projectId: 'demo-depar-review',
          token: () async => 'test-only-token',
          client: MockClient((_) async => response),
        );
        await expectLater(
          FirebaseAccountDeletion(api: api).deleteCurrentAccount(),
          throwsA(isA<SafetyApiException>()),
        );
      }
    },
  );
  test('missing authentication prevents network access', () async {
    var called = false;
    final api = SafetyApi(
      projectId: 'demo-depar-review',
      token: () async => null,
      client: MockClient((_) async {
        called = true;
        return http.Response('{}', 200);
      }),
    );
    await expectLater(
      api.call('safetyStatus'),
      throwsA(isA<SafetyApiException>()),
    );
    expect(called, isFalse);
  });
}
