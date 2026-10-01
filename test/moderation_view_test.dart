import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halisaha_app/core/services/safety_api.dart';
import 'package:halisaha_app/modules/moderation/views/moderation_view.dart';

class _Api extends SafetyApi {
  bool denied = false;
  String status = 'pending';
  final actions = <Map<String, dynamic>>[];
  @override
  Future<Map<String, dynamic>> call(
    String function, [
    Map<String, dynamic> data = const {},
  ]) async {
    if (denied) throw const SafetyApiException('PERMISSION_DENIED');
    if (function == 'reviewContentReport' ||
        function == 'applyModerationAction') {
      actions.add(data);
      return {'updated': true};
    }
    return {
      'items': [
        {
          'id': 'test-report',
          'type': 'user',
          'targetId': 'target',
          'reason': 'spam',
          'status': status,
          'version': 'v1',
          'preview': {'title': 'Test user'},
        },
      ],
    };
  }
}

void main() {
  testWidgets('moderator can see a queue and start a review', (tester) async {
    final api = _Api();
    await tester.pumpWidget(MaterialApp(home: ModerationView(api: api)));
    await tester.pumpAndSettle();
    expect(find.textContaining('target'), findsOneWidget);
    await tester.tap(find.text('İncelemeye Al'));
    await tester.pumpAndSettle();
    expect(api.actions, [
      {'reportId': 'test-report', 'status': 'reviewing'},
    ]);
  });
  testWidgets('server denial shows no report data', (tester) async {
    final api = _Api()..denied = true;
    await tester.pumpWidget(MaterialApp(home: ModerationView(api: api)));
    await tester.pumpAndSettle();
    expect(find.textContaining('Yetkinizi'), findsOneWidget);
    expect(find.text('İncelemeye Al'), findsNothing);
    expect(find.textContaining('target'), findsNothing);
  });
  testWidgets(
    'restriction requires explicit confirmation and sends reviewed version',
    (tester) async {
      final api = _Api()..status = 'reviewing';
      await tester.pumpWidget(MaterialApp(home: ModerationView(api: api)));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Hesabı Kısıtla'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Vazgeç'));
      await tester.pumpAndSettle();
      expect(api.actions, isEmpty);
      await tester.tap(find.text('Hesabı Kısıtla'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Onayla'));
      await tester.pumpAndSettle();
      expect(api.actions.single, {
        'reportId': 'test-report',
        'action': 'restrictAccount',
        'version': 'v1',
      });
    },
  );
}
