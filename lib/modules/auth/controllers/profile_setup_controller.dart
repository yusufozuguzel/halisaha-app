import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../../../routes/app_routes.dart';

class ProfileSetupController extends GetxController {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Selected default icon index
  final RxInt selectedIconIndex = 0.obs;

  // avatarUrl if picked from gallery
  final RxString avatarUrl = ''.obs;

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
    avatarUrl.value = '';
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
      
      final user = _auth.currentUser;
      if (user == null) {
        Get.snackbar("Hata", "Kullanıcı oturumu bulunamadı.");
        return;
      }

      isLoading.value = true;
      final File imageFile = File(image.path);
      
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('profile_images/${user.uid}.jpg');
          
      await storageRef.putFile(imageFile);
      final downloadUrl = await storageRef.getDownloadURL();

      avatarUrl.value = downloadUrl;
      Get.snackbar("Başarılı", "Fotoğraf eklendi.");
    } catch (e) {
      Get.snackbar("Hata", "Fotoğraf seçilemedi: ${e.toString()}");
      avatarUrl.value = '';
    } finally {
      isLoading.value = false;
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
      
      Map<String, dynamic> updates = {
        'fullName': fullNameController.text.trim(),
        'position': selectedPosition.value,
        'preferredFoot': selectedFoot.value,
        'city': cityController.text.trim(),
        'isProfileComplete': true,
      };

      if (avatarUrl.value.isNotEmpty) {
        updates['avatarUrl'] = avatarUrl.value;
        updates['avatarData'] = FieldValue.delete();
        updates['avatarType'] = FieldValue.delete();
      } else {
        updates['avatarType'] = 'icon';
        updates['avatarData'] = selectedIconIndex.value.toString();
        updates['avatarUrl'] = FieldValue.delete();
      }

      await _firestore.collection('users').doc(user.uid).set(
        updates, 
        SetOptions(merge: true)
      );

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
