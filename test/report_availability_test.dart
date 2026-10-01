import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halisaha_app/core/services/content_reports.dart';
import 'package:halisaha_app/widgets/report_content_dialog.dart';
import 'package:halisaha_app/core/services/safety_api.dart';

class _UnavailableApi extends SafetyApi {
  @override
  Future<Map<String, dynamic>> call(
    String function, [
    Map<String, dynamic> data = const {},
  ]) async {
    throw const SafetyApiException('UNAVAILABLE');
  }
}

void main() {
  test(
    'unavailable server is never presented as a successful submission',
    () async {
      final reports = ContentReports(api: _UnavailableApi());
      expect(await reports.isAvailable(), isFalse);
      await expectLater(
        reports.submit(
          type: ReportTarget.user,
          targetId: 'target',
          reason: ReportReason.spam,
        ),
        throwsA(isA<SafetyApiException>()),
      );
    },
  );

  testWidgets('unavailable moderation never claims a report was sent', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showReportContentDialog(
                context,
                type: ReportTarget.user,
                targetId: 'target',
                reports: ContentReports(api: _UnavailableApi()),
              ),
              child: const Text('Şikayet Et'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Şikayet Et'));
    await tester.pumpAndSettle();
    expect(find.textContaining('şu anda kullanılamıyor'), findsOneWidget);
    expect(find.text('Gönder'), findsNothing);
    expect(find.text('Şikayetiniz kaydedildi.'), findsNothing);
  });
}
