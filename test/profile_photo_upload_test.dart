import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:convert';
import 'package:halisaha_app/core/services/safety_api.dart';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:halisaha_app/core/services/profile_photo_upload.dart';

class IdentityTokenFixture implements IdTokenResult {
  IdentityTokenFixture(this.token, this.claims);
  @override
  final String? token;
  @override
  final Map<String, dynamic>? claims;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test(
    'account switching while native token refresh is pending rejects the credential',
    () async {
      var owner = 'alice';
      final refreshed = Completer<IdTokenResult>();
      final requestToken = profilePhotoTokenForOwner(
        'alice',
        currentUid: () => owner,
        getTokenResult: () => refreshed.future,
      );
      final rejected = expectLater(
        requestToken,
        throwsA(isA<ProfilePhotoException>()),
      );
      owner = 'bob';
      refreshed.complete(
        IdentityTokenFixture('bob-native-token', {
          'sub': 'bob',
          'user_id': 'bob',
        }),
      );
      await rejected;
    },
  );

  test(
    'native token subject mismatch is rejected even if UI switched back',
    () async {
      for (final claims in [
        <String, dynamic>{'sub': 'bob'},
        <String, dynamic>{'sub': 'alice', 'user_id': 'bob'},
        <String, dynamic>{},
      ]) {
        await expectLater(
          profilePhotoTokenForOwner(
            'alice',
            currentUid: () => 'alice',
            getTokenResult: () async =>
                IdentityTokenFixture('native-token', claims),
          ),
          throwsA(isA<ProfilePhotoException>()),
        );
      }
    },
  );

  test(
    'validated credential remains the original owner token after UI changes',
    () async {
      var owner = 'alice';
      final token = await profilePhotoTokenForOwner(
        'alice',
        currentUid: () => owner,
        getTokenResult: () async => IdentityTokenFixture('alice-native-token', {
          'sub': 'alice',
          'user_id': 'alice',
        }),
      );
      owner = 'bob';
      expect(token, 'alice-native-token');
      expect(owner, 'bob');
    },
  );

  const bucket = 'demo-review.appspot.com';
  const avatar =
      'https://firebasestorage.googleapis.com/v0/b/demo-review.appspot.com/o/profile_images%2Falice.jpg?alt=media&token=test-only-token';
  final image = Uint8List.fromList([255, 216, 255, 0]);

  test(
    'enabled moderation sends verified bytes without client-selected owner',
    () async {
      final calls = <String>[];
      final uploader = ProfilePhotoUploader(
        storageBucket: bucket,
        currentUid: () => 'alice',
        call: (function, data) async {
          calls.add(function);
          if (function == 'safetyStatus')
            return {'photoModerationEnabled': true};
          expect(data.keys.toSet(), {'imageBase64', 'contentType'});
          expect(base64Decode(data['imageBase64'] as String), image);
          expect(data['contentType'], 'image/jpeg');
          return {'avatarUrl': avatar};
        },
        legacyUpload: (_, _, _) async => fail('No direct Storage upload'),
      );
      expect(await uploader.upload(image, 'alice'), avatar);
      expect(calls, ['safetyStatus', 'uploadProfilePhoto']);
    },
  );

  test(
    'old backend alone permits compatibility upload with authoritative UID',
    () async {
      var writes = 0;
      final uploader = ProfilePhotoUploader(
        storageBucket: bucket,
        currentUid: () => 'alice',
        call: (_, _) async => {'available': true},
        legacyUpload: (bytes, type, uid) async {
          writes++;
          expect(uid, 'alice');
          expect(type, 'image/jpeg');
          expect(identical(bytes, image), true);
          return avatar;
        },
      );
      expect(await uploader.upload(image, 'alice'), avatar);
      expect(writes, 1);
    },
  );

  test('disabled or malformed capability cannot use legacy Storage', () async {
    for (final capability in [false, null, 'true', 1]) {
      final uploader = ProfilePhotoUploader(
        storageBucket: bucket,
        currentUid: () => 'alice',
        call: (function, _) async {
          expect(function, 'safetyStatus');
          return {'photoModerationEnabled': capability};
        },
        legacyUpload: (_, _, _) async =>
            fail('No fallback for disabled service'),
      );
      await expectLater(
        uploader.upload(image, 'alice'),
        throwsA(isA<ProfilePhotoException>()),
      );
    }
  });

  test(
    'denied scan and service/network failure preserve old photo without fallback',
    () async {
      for (final error in [
        const SafetyApiException('PERMISSION_DENIED'),
        const SafetyApiException('UNAVAILABLE'),
        StateError('network failure'),
      ]) {
        var storedPhoto = 'old-photo';
        final uploader = ProfilePhotoUploader(
          storageBucket: bucket,
          currentUid: () => 'alice',
          call: (function, _) async {
            if (function == 'safetyStatus')
              return {'photoModerationEnabled': true};
            throw error;
          },
          legacyUpload: (_, _, _) async {
            storedPhoto = 'new-photo';
            return avatar;
          },
        );
        await expectLater(
          uploader.upload(image, 'alice'),
          throwsA(isA<ProfilePhotoException>()),
        );
        expect(storedPhoto, 'old-photo');
      }
    },
  );

  test(
    'failed capability request does not treat unknown state as old backend',
    () async {
      final uploader = ProfilePhotoUploader(
        storageBucket: bucket,
        currentUid: () => 'alice',
        call: (_, _) async => throw StateError('offline'),
        legacyUpload: (_, _, _) async =>
            fail('No fallback after failed negotiation'),
      );
      await expectLater(
        uploader.upload(image, 'alice'),
        throwsA(isA<ProfilePhotoException>()),
      );
    },
  );

  test('arbitrary UID and account switch stop before upload', () async {
    var owner = 'alice';
    var calls = 0;
    final uploader = ProfilePhotoUploader(
      storageBucket: bucket,
      currentUid: () => owner,
      call: (_, _) async {
        calls++;
        owner = 'bob';
        return {};
      },
      legacyUpload: (_, _, _) async => fail('Switched account cannot upload'),
    );
    await expectLater(
      uploader.upload(image, 'bob'),
      throwsA(isA<ProfilePhotoException>()),
    );
    expect(calls, 0);
    await expectLater(
      uploader.upload(image, 'alice'),
      throwsA(isA<ProfilePhotoException>()),
    );
    expect(calls, 1);
  });

  test(
    'returned URL must identify this project bucket and exact owner object',
    () async {
      for (final url in [
        avatar.replaceFirst('alice', 'bob'),
        avatar.replaceFirst(bucket, 'foreign.appspot.com'),
        avatar.replaceFirst(
          'firebasestorage.googleapis.com',
          'example.invalid',
        ),
        avatar.replaceFirst('https:', 'http:'),
        null,
      ]) {
        final uploader = ProfilePhotoUploader(
          storageBucket: bucket,
          currentUid: () => 'alice',
          call: (function, _) async => function == 'safetyStatus'
              ? {'photoModerationEnabled': true}
              : {'avatarUrl': url},
          legacyUpload: (_, _, _) async =>
              fail('No fallback for invalid server response'),
        );
        await expectLater(
          uploader.upload(image, 'alice'),
          throwsA(isA<ProfilePhotoException>()),
        );
      }
    },
  );

  test(
    'identifies actual image signatures independently of the fixed object suffix',
    () {
      expect(
        profilePhotoContentType(Uint8List.fromList([255, 216, 255, 0])),
        'image/jpeg',
      );
      expect(
        profilePhotoContentType(
          Uint8List.fromList([137, 80, 78, 71, 13, 10, 26, 10]),
        ),
        'image/png',
      );
      expect(
        profilePhotoContentType(
          Uint8List.fromList([82, 73, 70, 70, 0, 0, 0, 0, 87, 69, 66, 80]),
        ),
        'image/webp',
      );
    },
  );
  test(
    'rejects empty, oversized, truncated and unsupported data before upload',
    () {
      for (final bytes in [
        Uint8List(0),
        Uint8List(maxProfilePhotoBytes + 1),
        Uint8List.fromList([255, 216]),
        Uint8List.fromList('<svg/>'.codeUnits),
        Uint8List.fromList([82, 73, 70, 70, 0, 0, 0, 0, 87, 65, 86, 69]),
      ]) {
        expect(
          () => profilePhotoContentType(bytes),
          throwsA(isA<ProfilePhotoException>()),
        );
      }
    },
  );
  test('accepts size limit exactly', () {
    final bytes = Uint8List(maxProfilePhotoBytes)
      ..setRange(0, 3, [255, 216, 255]);
    expect(profilePhotoContentType(bytes), 'image/jpeg');
  });
}
