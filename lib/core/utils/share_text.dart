// No verified download URL or working universal-link route is available yet.
const appInvitationText =
    'Halı saha ve futsal maçlarını DEPAR ile organize ediyoruz. '
    'DEPAR uygulamasında bize katıl!';

String matchInvitationText({
  required String title,
  required String date,
  String? venue,
}) =>
    'DEPAR maç daveti: $title\nTarih: $date'
    '${venue == null ? '' : '\nSaha: $venue'}'
    '\nMaçı DEPAR uygulamasında bulabilirsiniz.';
