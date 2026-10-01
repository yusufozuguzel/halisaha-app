import 'dart:io';
import 'dart:typed_data';
import 'package:firebase_storage/firebase_storage.dart';

class ProfilePhotoException implements Exception {
  const ProfilePhotoException(this.message);
  final String message;
}

const maxProfilePhotoBytes = 5 * 1024 * 1024;

// Inspect bytes, not the selected file extension. Storage rules independently
// enforce size and declared MIME; they cannot inspect image bytes.
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

Future<String> uploadProfilePhoto(File file, String uid) async {
  if (uid.isEmpty || uid.contains('/')) {
    throw const ProfilePhotoException('Oturum bilgisi doğrulanamadı.');
  }
  if (await file.length() > maxProfilePhotoBytes) {
    throw const ProfilePhotoException('Fotoğraf en fazla 5 MB olmalıdır.');
  }
  final bytes = await file.readAsBytes();
  final contentType = profilePhotoContentType(bytes);
  final reference = FirebaseStorage.instance.ref('profile_images/$uid.jpg');
  // Upload the same bytes that were checked; never infer MIME from the .jpg key.
  await reference.putData(bytes, SettableMetadata(contentType: contentType));
  return reference.getDownloadURL();
}
