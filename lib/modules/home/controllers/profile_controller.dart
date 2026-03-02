import 'dart:io';
import 'package:get/get.dart';

class ProfileController extends GetxController {
  // Profil verileri — uygulama açık kaldığı sürece hafızada tutulur
  final RxString name = 'Recep Onur Demiray'.obs;
  final RxString position = 'ORTA SAHA'.obs;
  final Rx<File?> avatarFile = Rx<File?>(null);
  final RxString avatarUrl = 'https://picsum.photos/seed/profile1/200/200'.obs;

  void updateProfile({
    required String newName,
    required String newPosition,
    File? newAvatarFile,
  }) {
    if (newName.trim().isNotEmpty) name.value = newName.trim();
    if (newPosition.trim().isNotEmpty) {
      position.value = newPosition.trim().toUpperCase();
    }
    if (newAvatarFile != null) avatarFile.value = newAvatarFile;
  }
}
