import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'authenticated_callable.dart';

class WritePolicyException implements Exception {
  const WritePolicyException(this.message);
  final String message;
}

class WritePolicy {
  WritePolicy({
    AuthenticatedCallable? call,
    bool Function()? emailVerified,
    String? Function()? currentUid,
    Future<void> Function()? refreshToken,
  }) : _call = call ?? authenticatedCallable,
       _verified =
           emailVerified ??
           (() => FirebaseAuth.instance.currentUser?.emailVerified == true),
       _uid = currentUid ?? (() => FirebaseAuth.instance.currentUser?.uid),
       _refresh =
           refreshToken ??
           (() async {
             await FirebaseAuth.instance.currentUser?.getIdToken(true);
           });
  final AuthenticatedCallable _call;
  final bool Function() _verified;
  final String? Function() _uid;
  final Future<void> Function() _refresh;
  Future<bool> prepare(String uid) async {
    try {
      final status = await _call('safetyStatus', {});
      if (status['abuseControlsEnabled'] != true) return false;
      if (_uid() != uid || !_verified()) {
        throw const WritePolicyException(
          'Bu i\u015flem i\u00e7in e-postan\u0131z\u0131 Ayarlar ekran\u0131ndan do\u011frulay\u0131n.',
        );
      }
      await _refresh();
      if (_uid() != uid)
        throw const WritePolicyException(
          'Oturum de\u011fi\u015fti. L\u00fctfen tekrar deneyin.',
        );
      return true;
    } on WritePolicyException {
      rethrow;
    } catch (_) {
      throw const WritePolicyException(
        '\u0130\u015flem kontrol edilemedi. Ba\u011flant\u0131n\u0131z\u0131 kontrol edin.',
      );
    }
  }
}

String writeLimitPath(String uid, String action) {
  if (uid.isEmpty ||
      uid.contains('/') ||
      !const {'matchCreate', 'followRequest'}.contains(action)) {
    throw const WritePolicyException('Ge\u00e7ersiz i\u015flem.');
  }
  return '_writeLimits/$uid/actions/$action';
}

Map<String, dynamic> writeLimitData(String targetId) => {
  'targetId': targetId,
  'updatedAt': FieldValue.serverTimestamp(),
};
