import 'package:firebase_auth/firebase_auth.dart';

import 'social_auth.dart';

enum DeletionProvider { password, google, apple, unsupported }

DeletionProvider deletionProvider(Iterable<String> providers) {
  // Apple consent must also be revoked for linked Apple accounts.
  if (providers.contains('apple.com')) return DeletionProvider.apple;
  if (providers.contains('google.com')) return DeletionProvider.google;
  if (providers.contains('password')) return DeletionProvider.password;
  return DeletionProvider.unsupported;
}

class DeletionUnavailable implements Exception {
  const DeletionUnavailable();
}

/// Must be supplied by a reviewed, retry-safe server workflow that cleans
/// Firestore/Storage and relations before removing Auth. No client admin writes.
abstract interface class AccountDeletionBackend {
  Future<void> prepareDeletion({String? expectedUid});
  Future<void> deleteCurrentAccount({String? expectedUid});
}

class AccountDeletion {
  AccountDeletion({this.backend, String? Function()? currentUid})
      : _currentUid = currentUid ??
            (() {
              try {
                return FirebaseAuth.instance.currentUser?.uid;
              } catch (_) {
                return null;
              }
            });

  final AccountDeletionBackend? backend;
  final String? Function() _currentUid;

  Future<bool> run({
    required Future<bool> Function() reauthenticate,
    required Future<void> Function() revokeAppleConsent,
    required bool hasApple,
  }) async {
    // Fail before credentials, revocation, or any mutation when unavailable.
    final service = backend;
    if (service == null) throw const DeletionUnavailable();
    final initialUid = _currentUid();
    if (!await reauthenticate()) return false;
    if (initialUid != null && _currentUid() != initialUid) {
      throw const DeletionUnavailable();
    }
    // Confirm deployment, server write guards and recent auth before revoking
    // Apple consent. The server derives the UID from the verified ID token.
    await service.prepareDeletion(expectedUid: initialUid);
    if (initialUid != null && _currentUid() != initialUid) {
      throw const DeletionUnavailable();
    }
    if (hasApple) await revokeAppleConsent();
    if (initialUid != null && _currentUid() != initialUid) {
      throw const DeletionUnavailable();
    }
    await service.deleteCurrentAccount(expectedUid: initialUid);
    return true;
  }
}

class AccountReauthentication {
  AccountReauthentication(this.user);

  final User user;
  String? _appleAuthorizationCode;

  Future<bool> authenticate(String password) async {
    switch (deletionProvider(user.providerData.map((p) => p.providerId))) {
      case DeletionProvider.password:
        if (password.isEmpty || user.email == null) {
          throw FirebaseAuthException(code: 'missing-password');
        }
        await user.reauthenticateWithCredential(
          EmailAuthProvider.credential(email: user.email!, password: password),
        );
      case DeletionProvider.google:
        final account = await createGoogleSignIn().signIn();
        if (account == null) return false;
        final tokens = await account.authentication;
        // Firebase rejects a credential belonging to another UID.
        await user.reauthenticateWithCredential(
          GoogleAuthProvider.credential(
            accessToken: tokens.accessToken,
            idToken: tokens.idToken,
          ),
        );
      case DeletionProvider.apple:
        final result = await user.reauthenticateWithProvider(
          AppleAuthProvider(),
        );
        _appleAuthorizationCode = result.additionalUserInfo?.authorizationCode;
        if (_appleAuthorizationCode == null ||
            _appleAuthorizationCode!.isEmpty) {
          throw FirebaseAuthException(code: 'missing-apple-authorization-code');
        }
      case DeletionProvider.unsupported:
        throw FirebaseAuthException(code: 'unsupported-provider');
    }
    return true;
  }

  Future<void> revokeAppleConsent() async {
    final code = _appleAuthorizationCode;
    if (code == null) {
      throw FirebaseAuthException(code: 'missing-apple-authorization-code');
    }
    try {
      await FirebaseAuth.instance.revokeTokenWithAuthorizationCode(code);
    } finally {
      _appleAuthorizationCode = null;
    }
  }
}
