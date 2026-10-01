import 'package:flutter_test/flutter_test.dart';
import 'package:halisaha_app/core/utils/share_text.dart';

void main() {
  test('invites retain match details without unverified links', () {
    final text = matchInvitationText(
      title: 'Akşam Maçı',
      date: '30/09/2026 20:00',
      venue: 'Merkez Saha',
    );
    expect(text, contains('Akşam Maçı'));
    expect(text, contains('30/09/2026 20:00'));
    expect(text, contains('Merkez Saha'));
    expect(text, contains('DEPAR'));
    expect(text, isNot(contains('http')));
    expect(appInvitationText, isNot(contains('http')));
    expect(
      matchInvitationText(title: 'Maç', date: 'Bugün'),
      isNot(contains('null')),
    );
  });
}
