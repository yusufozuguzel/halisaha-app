import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/services/account_deletion.dart';
import '../../../core/services/firebase_account_deletion.dart';
import '../../auth/controllers/auth_controller.dart';
import '../../../core/services/safety_api.dart';

class SettingsController extends GetxController {
  final _storage = GetStorage();
  final RxBool isDarkMode = true.obs;
  final RxBool isModerator = false.obs;

  @override
  void onInit() {
    super.onInit();
    bool storedTheme = _storage.read('isDarkMode') ?? true;
    isDarkMode.value = storedTheme;
    _loadModeratorRole();
  }

  Future<void> _loadModeratorRole() async {
    try {
      final token = await FirebaseAuth.instance.currentUser?.getIdTokenResult(
        true,
      );
      isModerator.value = token?.claims?['moderator'] == true;
    } catch (_) {
      isModerator.value = false;
    }
  }

  void toggleDarkMode(bool value) {
    isDarkMode.value = value;
    _storage.write('isDarkMode', value);
    Get.changeThemeMode(value ? ThemeMode.dark : ThemeMode.light);
  }

  bool get deletionRequiresPassword =>
      deletionProvider(
        FirebaseAuth.instance.currentUser?.providerData.map((p) => p.providerId) ??
            const Iterable.empty(),
      ) ==
      DeletionProvider.password;

  Future<void> deleteUserAccount(String password) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
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
    }
  }
}
