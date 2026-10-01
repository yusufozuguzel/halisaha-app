import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';

Future<XFile?> pickProfileImage(ImageSource source) async {
  try {
    return await ImagePicker().pickImage(
      source: source,
      maxWidth: 800,
      maxHeight: 800,
      requestFullMetadata: false,
    );
  } on PlatformException {
    Get.snackbar(
      'Fotoğraf seçilemedi',
      'Kamera veya fotoğraf erişimini cihaz ayarlarından kontrol edin. '
          'İsterseniz hazır bir avatar seçebilirsiniz.',
    );
    return null;
  }
}
