import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halisaha_app/core/services/account_deletion.dart';

class _Backend implements AccountDeletionBackend {
  _Backend(this.events);
  final List<String> events;
  @override
  Future<void> prepareDeletion() async => events.add('prepare');
  @override
  Future<void> deleteCurrentAccount() async => events.add('backend');
}

class _User extends Fake implements User {
  AuthCredential? received;
  @override
  String get email => 'test@example.invalid';
  @override
  List<UserInfo> get providerData => [_UserInfo()];
  @override
  Future<UserCredential> reauthenticateWithCredential(
    AuthCredential credential,
  ) async {
    received = credential;
    return _Credential();
  }
}

class _Credential extends Fake implements UserCredential {}

class _UnavailableBackend implements AccountDeletionBackend {
  @override
  Future<void> prepareDeletion() async => throw const DeletionUnavailable();
  @override
  Future<void> deleteCurrentAccount() async => fail('Deletion must not run');
}

class _UserInfo extends Fake implements UserInfo {
  @override
  String get providerId => 'password';
}

void main() {
  test('backend readiness failure prevents Apple token revocation', () async {
    var revoked = false;
    await expectLater(
      AccountDeletion(backend: _UnavailableBackend()).run(
        reauthenticate: () async => true,
        revokeAppleConsent: () async {
          revoked = true;
        },
        hasApple: true,
      ),
      throwsA(isA<DeletionUnavailable>()),
    );
    expect(revoked, isFalse);
  });
  test(
    'provider selection covers social, linked, password and unknown accounts',
    () {
      expect(deletionProvider(['password']), DeletionProvider.password);
      expect(deletionProvider(['google.com']), DeletionProvider.google);
      expect(deletionProvider(['apple.com']), DeletionProvider.apple);
      expect(
        deletionProvider(['password', 'google.com']),
        DeletionProvider.google,
      );
      expect(
        deletionProvider(['google.com', 'apple.com']),
        DeletionProvider.apple,
      );
      expect(deletionProvider([]), DeletionProvider.unsupported);
    },
  );
  test('email reauthentication receives the exact password', () async {
    final user = _User();
    await AccountReauthentication(user).authenticate('  test password  ');
    expect(
      (user.received as EmailAuthCredential).password,
      '  test password  ',
    );
    expect((user.received as EmailAuthCredential).email, user.email);
  });
  test(
    'missing backend stops before credentials, revocation or mutations',
    () async {
      var touched = false;
      await expectLater(
        AccountDeletion().run(
          reauthenticate: () async {
            touched = true;
            return true;
          },
          revokeAppleConsent: () async {
            touched = true;
          },
          hasApple: true,
        ),
        throwsA(isA<DeletionUnavailable>()),
      );
      expect(touched, isFalse);
    },
  );
  test(
    'Apple revocation follows reauth and precedes backend deletion',
    () async {
      final events = <String>[];
      expect(
        await AccountDeletion(backend: _Backend(events)).run(
          reauthenticate: () async {
            events.add('reauth');
            return true;
          },
          revokeAppleConsent: () async => events.add('revoke'),
          hasApple: true,
        ),
        isTrue,
      );
      expect(events, ['reauth', 'prepare', 'revoke', 'backend']);
    },
  );
  test('password and Google do not invoke Apple revocation', () async {
    final events = <String>[];
    await AccountDeletion(backend: _Backend(events)).run(
      reauthenticate: () async => true,
      revokeAppleConsent: () async => events.add('revoke'),
      hasApple: false,
    );
    expect(events, ['prepare', 'backend']);
  });
  test('cancel and reauth/revocation failures never invoke backend', () async {
    final events = <String>[];
    final deletion = AccountDeletion(backend: _Backend(events));
    expect(
      await deletion.run(
        reauthenticate: () async => false,
        revokeAppleConsent: () async => events.add('revoke'),
        hasApple: true,
      ),
      isFalse,
    );
    await expectLater(
      deletion.run(
        reauthenticate: () async =>
            throw FirebaseAuthException(code: 'user-mismatch'),
        revokeAppleConsent: () async => events.add('revoke'),
        hasApple: true,
      ),
      throwsA(isA<FirebaseAuthException>()),
    );
    await expectLater(
      deletion.run(
        reauthenticate: () async => true,
        revokeAppleConsent: () async => throw StateError('revocation-failed'),
        hasApple: true,
      ),
      throwsStateError,
    );
    expect(events, ['prepare']);
  });
}
