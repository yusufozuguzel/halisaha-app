import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:halisaha_app/core/services/profile_photo_upload.dart';

void main() {
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
