import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/services/username_service.dart';
import '../../../core/services/email_verification.dart';
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
  final RxBool needsEmailVerification = false.obs;
  final RxBool accountBusy = false.obs;
  final RxBool usernamesEnabled = false.obs;
  final RxString username = ''.obs;
  final usernameInput = TextEditingController();
  DateTime? _lastVerificationSent;

  @override
  void onClose() {
    usernameInput.dispose();
    super.onClose();
  }

  Future<void> _loadAccountFeatures() async {
    final user = FirebaseAuth.instance.currentUser;
    needsEmailVerification.value =
        user?.email != null && user?.emailVerified != true;
    if (user == null) return;
    try {
      final enabled = await UsernameService().enabled();
      final profile = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      if (isClosed || FirebaseAuth.instance.currentUser?.uid != user.uid)
        return;
      usernamesEnabled.value = enabled;
      username.value = profile.data()?['username'] as String? ?? '';
    } catch (_) {
      if (!isClosed) usernamesEnabled.value = false;
    }
  }

  Future<void> resendVerification() async {
    if (accountBusy.value) return;
    if (_lastVerificationSent != null &&
        DateTime.now().difference(_lastVerificationSent!).inSeconds < 60) {
      Get.snackbar(
        'E-posta do\u011frulama',
        'Yeni e-posta i\u00e7in bir dakika bekleyin.',
      );
      return;
    }
    accountBusy.value = true;
    try {
      await EmailVerificationService().send();
      _lastVerificationSent = DateTime.now();
      if (!isClosed)
        Get.snackbar(
          'E-posta g\u00f6nderildi',
          'Gelen kutunuzu ve spam klas\u00f6r\u00fcn\u00fc kontrol edin.',
        );
    } catch (_) {
      if (!isClosed)
        Get.snackbar(
          'E-posta g\u00f6nderilemedi',
          'L\u00fctfen daha sonra tekrar deneyin.',
        );
    } finally {
      if (!isClosed) accountBusy.value = false;
    }
  }

  Future<void> recheckVerification() async {
    if (accountBusy.value) return;
    accountBusy.value = true;
    try {
      final verified = await EmailVerificationService().refresh();
      if (isClosed) return;
      needsEmailVerification.value = !verified;
      Get.snackbar(
        'E-posta do\u011frulama',
        verified
            ? 'E-postan\u0131z do\u011fruland\u0131.'
            : 'Hen\u00fcz do\u011frulanmad\u0131. E-postadaki ba\u011flant\u0131ya dokunun.',
      );
    } catch (_) {
      if (!isClosed)
        Get.snackbar(
          'Kontrol tamamlanamad\u0131',
          'L\u00fctfen tekrar deneyin.',
        );
    } finally {
      if (!isClosed) accountBusy.value = false;
    }
  }

  Future<void> claimUsername() async {
    if (accountBusy.value ||
        username.value.isNotEmpty ||
        !usernamesEnabled.value)
      return;
    final owner = FirebaseAuth.instance.currentUser?.uid;
    accountBusy.value = true;
    try {
      final claimed = await UsernameService().claim(usernameInput.text);
      if (!isClosed && FirebaseAuth.instance.currentUser?.uid == owner) {
        username.value = claimed;
        Get.snackbar('Kullan\u0131c\u0131 ad\u0131', '@$claimed kaydedildi.');
      }
    } catch (error) {
      if (!isClosed)
        Get.snackbar(
          'Kullan\u0131c\u0131 ad\u0131 kaydedilemedi',
          error is UsernameException
              ? error.message
              : 'L\u00fctfen tekrar deneyin.',
        );
    } finally {
      if (!isClosed) accountBusy.value = false;
    }
  }

  @override
  void onInit() {
    super.onInit();
    bool storedTheme = _storage.read('isDarkMode') ?? true;
    isDarkMode.value = storedTheme;
    _loadModeratorRole();
    _loadAccountFeatures();
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
        FirebaseAuth.instance.currentUser?.providerData.map(
              (p) => p.providerId,
            ) ??
            const Iterable.empty(),
      ) ==
      DeletionProvider.password;

  Future<void> deleteUserAccount(String password) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      final reauthentication = AccountReauthentication(user);
      final accepted = await AccountDeletion(backend: FirebaseAccountDeletion())
          .run(
            reauthenticate: () => reauthentication.authenticate(password),
            revokeAppleConsent: reauthentication.revokeAppleConsent,
            hasApple: user.providerData.any((p) => p.providerId == 'apple.com'),
          );
      if (accepted) {
        await Get.find<AuthController>().logout();
        Get.snackbar(
          'Silme talebiniz alındı',
          'Oturumunuz kapatıldı. Hesabınız ve ilişkili verileriniz sunucuda siliniyor.',
        );
      }
    } on SafetyApiException catch (e) {
      Get.snackbar(
        'İşlem tamamlanamadı',
        e.code == 'FAILED_PRECONDITION'
            ? 'Lütfen yeniden giriş yapıp tekrar deneyin.'
            : 'Silme hizmetine ulaşılamadı. Daha sonra tekrar deneyebilirsiniz.',
      );
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
