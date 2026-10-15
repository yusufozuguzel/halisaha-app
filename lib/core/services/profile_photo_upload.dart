import 'dart:io';
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'safety_api.dart';
import 'dart:typed_data';
import 'package:firebase_storage/firebase_storage.dart';

class ProfilePhotoException implements Exception {
  const ProfilePhotoException(this.message);
  final String message;
}

const maxProfilePhotoBytes = 5 * 1024 * 1024;

// Inspect bytes, not the selected extension. The moderated server independently
// checks size, signature and actual contents before publishing; Storage rules
// reject direct writes in the new candidate.
String profilePhotoContentType(Uint8List bytes) {
  if (bytes.isEmpty || bytes.length > maxProfilePhotoBytes) {
    throw const ProfilePhotoException(
      'Fotoğraf boş olmamalı ve en fazla 5 MB olmalıdır.',
    );
  }
  bool starts(List<int> signature) =>
      bytes.length >= signature.length &&
      List.generate(
        signature.length,
        (i) => bytes[i] == signature[i],
      ).every((same) => same);
  if (starts([0xff, 0xd8, 0xff])) return 'image/jpeg';
  if (starts([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a])) {
    return 'image/png';
  }
  if (starts([0x52, 0x49, 0x46, 0x46]) &&
      bytes.length >= 12 &&
      bytes[8] == 0x57 &&
      bytes[9] == 0x45 &&
      bytes[10] == 0x42 &&
      bytes[11] == 0x50) {
    return 'image/webp';
  }
  throw const ProfilePhotoException(
    'Lütfen JPEG, PNG veya WebP biçiminde bir fotoğraf seçin.',
  );
}

typedef PhotoCallable =
    Future<Map<String, dynamic>> Function(
      String function,
      Map<String, dynamic> data,
    );
typedef LegacyPhotoUpload =
    Future<String> Function(Uint8List bytes, String contentType, String uid);

/// Only an absent capability flag means an old backend. A disabled service,
/// failed capability request or rejected scan never falls through to Storage.
class ProfilePhotoUploader {
  ProfilePhotoUploader({
    required this.currentUid,
    required this.call,
    required this.legacyUpload,
    required this.storageBucket,
  });
  final String? Function() currentUid;
  final PhotoCallable call;
  final String storageBucket;
  final LegacyPhotoUpload legacyUpload;

  void _requireOwner(String uid) {
    if (uid.isEmpty || uid.contains('/') || currentUid() != uid) {
      throw const ProfilePhotoException(
        'Oturum bilgisi do\u011frulanamad\u0131.',
      );
    }
  }

  Future<String> upload(Uint8List bytes, String uid) async {
    _requireOwner(uid);
    final contentType = profilePhotoContentType(bytes);
    try {
      final status = await call('safetyStatus', {});
      _requireOwner(uid);
      if (!status.containsKey('photoModerationEnabled')) {
        final url = await legacyUpload(bytes, contentType, uid);
        _requireOwner(uid);
        return validatedProfilePhotoUrl(url, uid, storageBucket);
      }
      if (status['photoModerationEnabled'] != true) {
        throw const ProfilePhotoException(
          'Foto\u011fraf kontrol hizmeti haz\u0131r de\u011fil. L\u00fctfen daha sonra tekrar deneyin.',
        );
      }
      final result = await call('uploadProfilePhoto', {
        'imageBase64': base64Encode(bytes),
        'contentType': contentType,
      });
      _requireOwner(uid);
      return validatedProfilePhotoUrl(result['avatarUrl'], uid, storageBucket);
    } on ProfilePhotoException {
      rethrow;
    } on SafetyApiException catch (error) {
      throw ProfilePhotoException(
        error.code == 'PERMISSION_DENIED'
            ? 'Foto\u011fraf onaylanmad\u0131. L\u00fctfen ba\u015fka bir foto\u011fraf se\u00e7in.'
            : 'Foto\u011fraf kontrol\u00fc tamamlanamad\u0131. L\u00fctfen tekrar deneyin.',
      );
    } catch (_) {
      throw const ProfilePhotoException(
        'Foto\u011fraf y\u00fcklenemedi. Ba\u011flant\u0131n\u0131z\u0131 kontrol edip tekrar deneyin.',
      );
    }
  }
}

String validatedProfilePhotoUrl(dynamic value, String uid, String bucket) {
  final uri = value is String ? Uri.tryParse(value) : null;
  final expectedPath = ['v0', 'b', bucket, 'o', 'profile_images/$uid.jpg'];
  if (uri == null ||
      uri.scheme != 'https' ||
      uri.host != 'firebasestorage.googleapis.com' ||
      uri.hasPort ||
      uri.userInfo.isNotEmpty ||
      uri.fragment.isNotEmpty ||
      bucket.isEmpty ||
      uri.pathSegments.length != expectedPath.length ||
      List.generate(
        expectedPath.length,
        (i) => uri.pathSegments[i] != expectedPath[i],
      ).any((different) => different) ||
      uri.queryParameters['alt'] != 'media' ||
      (uri.queryParameters['token'] ?? '').isEmpty) {
    throw const ProfilePhotoException(
      'Foto\u011fraf adresi do\u011frulanamad\u0131. L\u00fctfen tekrar deneyin.',
    );
  }
  return value as String;
}

/// Bind this request to the owner who selected the photo. SDK claims are a
/// local consistency check; the callable still verifies the token server-side.
Future<String> profilePhotoTokenForOwner(
  String ownerUid, {
  required String? Function() currentUid,
  required Future<IdTokenResult> Function() getTokenResult,
}) async {
  void requireOwner() {
    if (ownerUid.isEmpty || currentUid() != ownerUid) {
      throw const ProfilePhotoException(
        'Oturum de\u011fi\u015fti. Foto\u011fraf\u0131 yeniden se\u00e7in.',
      );
    }
  }

  requireOwner();
  final result = await getTokenResult();
  // The native SDK can switch users while token acquisition is in flight.
  requireOwner();
  final claims = result.claims;
  final identities = [
    claims?['sub'],
    claims?['user_id'],
  ].where((claim) => claim != null).toList();
  final token = result.token;
  if (identities.isEmpty ||
      identities.any((claim) => claim != ownerUid) ||
      token == null ||
      token.isEmpty) {
    throw const ProfilePhotoException(
      'Oturum bilgisi do\u011frulanamad\u0131. L\u00fctfen tekrar giri\u015f yap\u0131n.',
    );
  }
  return token;
}

Future<String> uploadProfilePhoto(File file, String uid) async {
  final auth = FirebaseAuth.instance;
  final owner = auth.currentUser;
  if (owner?.uid != uid || uid.isEmpty || uid.contains('/')) {
    throw const ProfilePhotoException(
      'Oturum bilgisi do\u011frulanamad\u0131.',
    );
  }
  try {
    if (await file.length() > maxProfilePhotoBytes) {
      throw const ProfilePhotoException(
        'Foto\u011fraf en fazla 5 MB olmal\u0131d\u0131r.',
      );
    }
    final bytes = await file.readAsBytes();
    final api = SafetyApi(
      token: () => profilePhotoTokenForOwner(
        uid,
        currentUid: () => auth.currentUser?.uid,
        getTokenResult: () => owner!.getIdTokenResult(true),
      ),
    );
    return await ProfilePhotoUploader(
      storageBucket: Firebase.app().options.storageBucket ?? '',
      currentUid: () => auth.currentUser?.uid,
      call: (function, data) => api.call(function, data),
      legacyUpload: (bytes, contentType, ownerUid) async {
        final reference = FirebaseStorage.instance.ref(
          'profile_images/$ownerUid.jpg',
        );
        await reference.putData(
          bytes,
          SettableMetadata(contentType: contentType),
        );
        return reference.getDownloadURL();
      },
    ).upload(bytes, uid);
  } on ProfilePhotoException {
    rethrow;
  } catch (_) {
    throw const ProfilePhotoException(
      'Foto\u011fraf okunamad\u0131 veya y\u00fcklenemedi. L\u00fctfen tekrar deneyin.',
    );
  }
}
