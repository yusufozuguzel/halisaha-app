import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:halisaha_app/core/services/username_service.dart';
import 'package:halisaha_app/core/services/email_verification.dart';
import 'package:halisaha_app/core/services/write_policy.dart';

void main() {
  test(
    'optional handles normalize ASCII and do not accept ambiguous display names',
    () {
      expect(normalizeUsername(' Player_1 '), 'player_1');
      for (final input in [
        'ab',
        'a' * 31,
        'full name',
        'a/b',
        'name@example.invalid',
      ]) {
        expect(
          () => normalizeUsername(input),
          throwsA(isA<UsernameException>()),
        );
      }
    },
  );
  test(
    'disabled username service cannot claim while legacy naming remains untouched',
    () async {
      final service = UsernameService(
        currentUid: () => 'alice',
        call: (function, _) async {
          expect(function, 'safetyStatus');
          return {};
        },
      );
      await expectLater(
        service.claim('player'),
        throwsA(isA<UsernameException>()),
      );
    },
  );
  test(
    'account switch during username capability check prevents irreversible claim',
    () async {
      var owner = 'alice';
      final gate = Completer<Map<String, dynamic>>();
      final service = UsernameService(
        currentUid: () => owner,
        call: (function, _) async {
          if (function == 'safetyStatus') return gate.future;
          fail('Claim cannot use another account');
        },
      );
      final claim = service.claim('player');
      final rejected = expectLater(claim, throwsA(isA<UsernameException>()));
      owner = 'bob';
      gate.complete({'usernamesEnabled': true});
      await rejected;
    },
  );
  test(
    'claim and exact lookup use only normalized handle and a unique claimed UID',
    () async {
      final service = UsernameService(
        currentUid: () => 'alice',
        call: (function, data) async {
          if (function == 'safetyStatus') return {'usernamesEnabled': true};
          expect(data, {'username': 'player'});
          return function == 'claimUsername'
              ? {'username': 'player'}
              : {'available': false, 'uid': 'bob'};
        },
      );
      expect(await service.claim('Player'), 'player');
      expect(await service.find('@Player'), 'bob');
    },
  );
  test(
    'verification recheck reloads account then forces credential refresh',
    () async {
      final steps = <String>[];
      final verified = await refreshEmailVerification(
        ownerUid: 'alice',
        currentUid: () => 'alice',
        reload: () async {
          steps.add('reload');
        },
        refreshToken: () async {
          steps.add('token');
        },
        verified: () => true,
      );
      expect(verified, true);
      expect(steps, ['reload', 'token']);
    },
  );
  test(
    'account switch after reload blocks token refresh and verification attribution',
    () async {
      var owner = 'alice';
      await expectLater(
        refreshEmailVerification(
          ownerUid: 'alice',
          currentUid: () => owner,
          reload: () async {
            owner = 'bob';
          },
          refreshToken: () async => fail('No new owner token'),
          verified: () => true,
        ),
        throwsA(isA<VerificationSessionChanged>()),
      );
    },
  );
  test(
    'legacy unverified accounts remain enabled until trusted abuse policy turns on',
    () async {
      final policy = WritePolicy(
        call: (_, _) async => {},
        currentUid: () => 'alice',
        emailVerified: () => false,
        refreshToken: () async => fail('No forced refresh when disabled'),
      );
      expect(await policy.prepare('alice'), false);
      final gated = WritePolicy(
        call: (_, _) async => {'abuseControlsEnabled': true},
        currentUid: () => 'alice',
        emailVerified: () => false,
        refreshToken: () async => fail('Unverified account cannot proceed'),
      );
      await expectLater(
        gated.prepare('alice'),
        throwsA(isA<WritePolicyException>()),
      );
    },
  );
  test(
    'verified gated actions refresh identity and use fixed atomic limiter paths',
    () async {
      var refreshed = false;
      final policy = WritePolicy(
        call: (_, _) async => {'abuseControlsEnabled': true},
        currentUid: () => 'alice',
        emailVerified: () => true,
        refreshToken: () async {
          refreshed = true;
        },
      );
      expect(await policy.prepare('alice'), true);
      expect(refreshed, true);
      expect(
        writeLimitPath('alice', 'matchCreate'),
        '_writeLimits/alice/actions/matchCreate',
      );
      expect(writeLimitData('target').keys.toSet(), {'targetId', 'updatedAt'});
    },
  );
}
