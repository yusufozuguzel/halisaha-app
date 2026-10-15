import 'package:firebase_auth/firebase_auth.dart';

class VerificationSessionChanged implements Exception {
  const VerificationSessionChanged();
}

Future<bool> refreshEmailVerification({
  required String ownerUid,
  required String? Function() currentUid,
  required Future<void> Function() reload,
  required Future<void> Function() refreshToken,
  required bool Function() verified,
}) async {
  void check() {
    if (currentUid() != ownerUid) throw const VerificationSessionChanged();
  }

  check();
  await reload();
  check();
  await refreshToken();
  check();
  return verified();
}

class EmailVerificationService {
  Future<void> send() async {
    final auth = FirebaseAuth.instance;
    final user = auth.currentUser;
    if (user == null || user.email == null || user.emailVerified) return;
    await user.sendEmailVerification();
    if (auth.currentUser?.uid != user.uid)
      throw const VerificationSessionChanged();
  }

  Future<bool> refresh() async {
    final auth = FirebaseAuth.instance;
    final user = auth.currentUser;
    if (user == null) throw const VerificationSessionChanged();
    return refreshEmailVerification(
      ownerUid: user.uid,
      currentUid: () => auth.currentUser?.uid,
      reload: user.reload,
      refreshToken: () async {
        await auth.currentUser?.getIdTokenResult(true);
      },
      verified: () => auth.currentUser?.emailVerified == true,
    );
  }
}
