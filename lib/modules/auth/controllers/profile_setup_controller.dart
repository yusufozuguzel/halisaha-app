import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../routes/app_routes.dart';

class ProfileSetupController extends GetxController {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Selected default icon index
  final RxInt selectedIconIndex = 0.obs;

  // Base64 encoded Image if picked from gallery
  final RxString base64ImageData = ''.obs;

  // Form Fields
  final fullNameController = TextEditingController();
  final cityController = TextEditingController();

  // Dropdown states
  final RxString selectedPosition = 'Forvet'.obs;
  final RxString selectedFoot = 'Sağ'.obs;

  // Loading state
  final RxBool isLoading = false.obs;

  final List<IconData> defaultIcons = [
    Icons.person,
    Icons.sports_soccer,
    Icons.sports_martial_arts,
    Icons.face,
  ];

  final List<String> positions = ['Forvet', 'Orta Saha', 'Defans', 'Kaleci'];
  final List<String> feet = ['Sağ', 'Sol', 'İki Ayak'];

  @override
  void onInit() {
    super.onInit();
    _fetchUserData();
  }

  Future<void> _fetchUserData() async {
    final user = _auth.currentUser;
    if (user != null) {
      if (user.displayName != null && user.displayName!.isNotEmpty) {
        fullNameController.text = user.displayName!;
      } else {
        try {
          final doc = await _firestore.collection('users').doc(user.uid).get();
          if (doc.exists) {
            final data = doc.data() as Map<String, dynamic>;
            // The AuthController uses "name" for the fullName from registration
            final name = data['name'] ?? '';
            if (name.isNotEmpty) {
              fullNameController.text = name;
            }
          }
        } catch (e) {
          // Ignore error silently
        }
      }
    }
  }

  @override
  void onClose() {
    fullNameController.dispose();
    cityController.dispose();
    super.onClose();
  }

  void selectIcon(int index) {
    selectedIconIndex.value = index;
    // Clear custom image if icon selected
    base64ImageData.value = '';
  }

  Future<void> pickImageFromGallery() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        // Optional quick limit via ImagePicker natively
        maxWidth: 800,
        maxHeight: 800,
      );

      if (image == null) return;

      final bytes = await image.readAsBytes();

      // HEAVY COMPRESSION LOGIC
      final compressedBytes = await FlutterImageCompress.compressWithList(
        bytes,
        minWidth: 250,
        minHeight: 250,
        quality: 60,
      );

      // Convert to Base64
      base64ImageData.value = base64Encode(compressedBytes);
      Get.snackbar("Başarılı", "Fotoğraf eklendi.");
    } catch (e) {
      Get.snackbar("Hata", "Fotoğraf seçilemedi: ${e.toString()}");
      base64ImageData.value = '';
    }
  }

  Future<void> saveProfile() async {
    if (fullNameController.text.trim().isEmpty) {
      Get.snackbar("Hata", "Lütfen adınızı girin.");
      return;
    }

    if (cityController.text.trim().isEmpty) {
      Get.snackbar("Hata", "Lütfen şehrinizi girin.");
      return;
    }

    final user = _auth.currentUser;
    if (user == null) {
      Get.snackbar("Hata", "Kullanıcı oturumu bulunamadı.");
      return;
    }

    try {
      isLoading.value = true;
      String avatarType = 'icon';
      String avatarData = selectedIconIndex.value.toString();

      if (base64ImageData.value.isNotEmpty) {
        avatarType = 'base64';
        avatarData = base64ImageData.value;
      }

      await _firestore.collection('users').doc(user.uid).set({
        'fullName': fullNameController.text.trim(),
        'position': selectedPosition.value,
        'preferredFoot': selectedFoot.value,
        'city': cityController.text.trim(),
        'avatarType': avatarType,
        'avatarData': avatarData,
        'isProfileComplete': true,
      }, SetOptions(merge: true));

      Get.offAllNamed(Routes.HOME);
    } catch (e) {
      Get.snackbar(
        "Hata",
        "Profil kaydedilirken bir hata oluştu: ${e.toString()}",
      );
    } finally {
      isLoading.value = false;
    }
  }
}
