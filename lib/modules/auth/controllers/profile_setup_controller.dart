import 'dart:io';
import '../../../core/services/profile_image_picker.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/services/profile_photo_upload.dart';
import '../../../routes/app_routes.dart';
import '../../../core/services/account_deletion.dart';
import '../../../core/services/firebase_account_deletion.dart';
import '../../../core/services/safety_api.dart';
import '../../auth/controllers/auth_controller.dart';
import '../../../core/services/content_filter.dart';

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
    if (isLoading.value) return;
    try {
      final XFile? image = await pickProfileImage(ImageSource.gallery);

      if (image == null) return;
      
      final user = _auth.currentUser;
      if (user == null) {
        Get.snackbar("Hata", "Kullanıcı oturumu bulunamadı.");
        return;
      }

      isLoading.value = true;
      final File imageFile = File(image.path);
      
      final downloadUrl = await uploadProfilePhoto(imageFile, user.uid);
      if (isClosed || _auth.currentUser?.uid != user.uid) return;

      avatarUrl.value = downloadUrl;
      Get.snackbar("Başarılı", "Fotoğraf eklendi.");
    } catch (e) {
      Get.snackbar('Fotoğraf yüklenemedi', e is ProfilePhotoException
          ? e.message : 'Fotoğraf yüklenemedi. Bağlantınızı ve hesap durumunuzu kontrol edin.');
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
    if (fullNameController.text.trim().length > 100 ||
        cityController.text.trim().length > 100) {
      Get.snackbar('Hata', 'Ad ve şehir en fazla 100 karakter olabilir.');
      return;
    }

    final user = _auth.currentUser;
    if (user == null) {
      Get.snackbar("Hata", "Kullanıcı oturumu bulunamadı.");
      return;
    }

    try {
      // İçerik Filtreleme Kontrolü
      final contentFilter = Get.put(ContentFilterService());
      contentFilter.validateTexts([
        fullNameController.text,
        cityController.text,
      ]);
      
      isLoading.value = true;
      
      Map<String, dynamic> updates = {
        'profileVersion': 2,
        'email': FieldValue.delete(),
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
    } on ContentFilterException catch (e) {
      Get.snackbar('Uygunsuz İçerik', e.message,
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.redAccent,
          colorText: Colors.white);
    } catch (e) {
      Get.snackbar(
        "Hata",
        "Profil kaydedilirken bir hata oluştu: ${e.toString()}",
      );
    } finally {
      isLoading.value = false;
    }
  }

  bool get deletionRequiresPassword =>
      deletionProvider(
        _auth.currentUser?.providerData.map((p) => p.providerId) ??
            const Iterable.empty(),
      ) ==
      DeletionProvider.password;

  Future<void> deleteUserAccount(String password) async {
    final user = _auth.currentUser;
    if (user == null || isLoading.value) return;
    isLoading.value = true;
    try {
      final reauthentication = AccountReauthentication(user);
      final accepted = await AccountDeletion(backend: FirebaseAccountDeletion()).run(
        reauthenticate: () => reauthentication.authenticate(password),
        revokeAppleConsent: reauthentication.revokeAppleConsent,
        hasApple: user.providerData.any((p) => p.providerId == 'apple.com'),
      );
      if (accepted) {
        await Get.find<AuthController>().logout();
        Get.snackbar('Silme talebiniz alındı',
            'Oturumunuz kapatıldı. Hesabınız ve ilişkili verileriniz sunucuda siliniyor.');
      }
    } on SafetyApiException catch (e) {
      Get.snackbar('İşlem tamamlanamadı',
          e.code == 'FAILED_PRECONDITION'
              ? 'Lütfen yeniden giriş yapıp tekrar deneyin.'
              : 'Silme hizmetine ulaşılamadı. Daha sonra tekrar deneyebilirsiniz.');
    } on DeletionUnavailable {
      Get.snackbar(
        'Hesap silme şu anda kullanılamıyor',
        'Güvenli hesap silme hizmeti henüz hazır değil. Hiçbir veriniz silinmedi. Lütfen daha sonra tekrar deneyin.',
      );
    } on FirebaseAuthException catch (e) {
      if (e.code == 'canceled' ||
          e.code == 'web-context-canceled' ||
          e.code == 'user-cancelled') {
        return;
      }
      Get.snackbar(
        'İşlem tamamlanamadı',
        'Kimliğiniz doğrulanamadı. Mevcut hesabınızın giriş bilgileriyle tekrar deneyin.',
      );
    } catch (_) {
      Get.snackbar(
        'İşlem tamamlanamadı',
        'Lütfen bağlantınızı kontrol edip tekrar deneyin.',
      );
    } finally {
      isLoading.value = false;
    }
  }
}

