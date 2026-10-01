import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/services/profile_photo_upload.dart';
import '../../../core/services/account_deletion.dart';
import '../../../core/services/firebase_account_deletion.dart';
import '../../../core/services/safety_api.dart';
import '../../../core/services/social_interactions.dart';
import '../../auth/controllers/auth_controller.dart';
import '../../friends/controllers/block_controller.dart';

class ProfileController extends GetxController {
  // ── Kimlik ────────────────────────────────────────────────
  /// Görüntülenen kullanıcının UID'si.
  /// Kendi profilimizse FirebaseAuth.currentUser.uid ile aynı.
  late final String targetUid;

  /// true → kendi profilimizse
  late final bool isOwnProfile;

  // ── Profil verileri ────────────────────────────────────────
  final RxString name = 'Yükleniyor...'.obs;
  final RxString position = ''.obs;

  /// Dropdown seçimi için reaktif değişken — edit sheet bunu kullanır.
  final RxString selectedPosition = ''.obs;
  final Rx<File?> avatarFile = Rx<File?>(null);
  final RxString avatarUrl = ''.obs;

  // ── Takip durumu ───────────────────────────────────────────
  final RxBool isFriend = false.obs;
  final RxBool isPending = false.obs;
  final RxBool isLoading = false.obs;
  final RxBool isBlocked = false.obs;

  // ── İstatistikler ──────────────────────────────────────────
  final RxInt matchesCount = 0.obs;
  final RxInt friendsCount = 0.obs;

  // ── Upload durumu ──────────────────────────────────────────
  // ── Upload durumu ──────────────────────────────────────────
  final RxBool isUploading = false.obs;

  // ── Şifre Değiştirme Durumu ────────────────────────────────
  // Form key for password change
  final GlobalKey<FormState> changePasswordFormKey = GlobalKey<FormState>();

  var currentPassword = ''.obs;
  var newPassword = ''.obs;
  final RxString confirmPassword = "".obs;
  final RxBool isCurrentObscure = true.obs;
  final RxBool isNewObscure = true.obs;
  final RxBool isConfirmObscure = true.obs;

  // Using Form validation now, old manual computed values not needed but keeping for compatibility if used elsewhere
  bool get isLengthValid => newPassword.value.length >= 8;
  bool get isComplexValid => RegExp(r'[A-Z]').hasMatch(newPassword.value) && RegExp(r'[!@#\$%^&*(),.?":{}|<>]').hasMatch(newPassword.value);
  bool get isMatchValid => newPassword.value == confirmPassword.value;

  // ── Şifre Güncelle ──────────────────────────────────────────|──
  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  String? get _myUid => _auth.currentUser?.uid;

  bool get hasPasswordProvider =>
      _auth.currentUser?.providerData.any(
        (info) => info.providerId == 'password',
      ) ??
      false;

  bool get deletionRequiresPassword =>
      deletionProvider(
        _auth.currentUser?.providerData.map((p) => p.providerId) ??
            const <String>[],
      ) ==
      DeletionProvider.password;

  // ── Subscriptions ──────────────────────────────────────────
  final List<Function()> _subs = [];

  // ──────────────────────────────────────────────────────────
  @override
  void onInit() {
    super.onInit();

    // Get.arguments → {'uid': 'someUID'} veya null (kendi profili)
    final args = Get.arguments;
    final argUid = (args is Map && args['uid'] != null)
        ? args['uid'] as String
        : null;

    final myUid = _myUid ?? '';
    targetUid = argUid ?? myUid;
    isOwnProfile = targetUid == myUid || targetUid.isEmpty;
    if (!isOwnProfile) {
      final blocks = BlockController.shared;
      isBlocked.value = blocks.isBlocked(targetUid);
      final worker = ever(blocks.blockedUserIds, (_) {
        if (isClosed) return;
        isBlocked.value = blocks.isBlocked(targetUid);
        if (isBlocked.value) { isFriend.value = false; isPending.value = false; }
      });
      _subs.add(worker.dispose);
    }

    _subscribeToProfile();
    _subscribeToStats();
    if (!isOwnProfile) _loadFollowState();
  }

  @override
  void onClose() {
    for (final cancel in _subs) {
      cancel();
    }
    super.onClose();
  }

  // ── Realtime profile subscription ─────────────────────────
  void _subscribeToProfile() {
    if (targetUid.isEmpty) return;
    final sub = _db.collection('users').doc(targetUid).snapshots().listen((
      snap,
    ) {
      if (!snap.exists) return;
      final d = snap.data() ?? {};
      name.value = d['fullName'] ?? d['name'] ?? '';
      position.value = d['position'] ?? '';
      // Dropdown başlangıç değerini Firestore'dan senkronize et
      const validPositions = ['Kaleci', 'Defans', 'Orta Saha', 'Forvet'];
      final raw = (d['position'] ?? '').toString();
      // Eski veriler büyük harfle kaydedilmiş olabilir; normalize et
      final normalized = validPositions.firstWhere(
        (p) => p.toUpperCase() == raw.toUpperCase(),
        orElse: () => validPositions.first,
      );
      if (selectedPosition.value.isEmpty) selectedPosition.value = normalized;
    });
    _subs.add(sub.cancel);

    // KULLANICININ ARKADAŞ LİSTESİ (FOLLOWING ALT KOLEKSİYONU ÜZERİNDEN HESAPLANIR)
    final friendsSub = _db
        .collection('users')
        .doc(targetUid)
        .collection('friends')
        .snapshots()
        .listen((snap) {
          friendsCount.value = snap.docs.length;
        });
    _subs.add(friendsSub.cancel);
  }

  // ── Stats: match count ─────────────────────────────────────
  void _subscribeToStats() {
    if (targetUid.isEmpty) return;
    final sub = _db
        .collection('matches')
        .where('currentPlayers', arrayContains: targetUid)
        .snapshots()
        .listen((snap) {
          matchesCount.value = snap.docs.length;
        });
    _subs.add(sub.cancel);
  }

  // ── Follow state (only for other profiles) ─────────────────
  Future<void> _loadFollowState() async {
    final myUid = _myUid;
    if (myUid == null || myUid.isEmpty || targetUid.isEmpty) return;

    // Engelledi mi? (Engel varsa takip bilgisi gerekmez)
    isBlocked.value = BlockController.shared.isBlocked(targetUid);

    // Engellenmişse takip durumunu kontrol etmeye gerek yok
    if (isBlocked.value) return;

    // Takip ediyor mu?
    final followerDoc = await _db
        .collection('users')
        .doc(targetUid)
        .collection('friends')
        .doc(myUid)
        .get();
    if (isClosed || _myUid != myUid || BlockController.shared.isBlocked(targetUid)) return;
    isFriend.value = followerDoc.exists;

    // İstek gönderildi mi?
    if (!isFriend.value) {
      final reqDoc = await _db
          .collection('users')
          .doc(targetUid)
          .collection('followRequests')
          .doc(myUid)
          .get();
      if (isClosed || _myUid != myUid || BlockController.shared.isBlocked(targetUid)) return;
      isPending.value = reqDoc.exists;
    }
  }

  // ── Block User (Instagram-style) ──────────────────────────────
  Future<void> blockUser() async {
    final myUid = _myUid;
    if (myUid == null || myUid.isEmpty || targetUid.isEmpty) return;
    try {
      isLoading.value = true;
      await SocialInteractions().block(targetUid);
      if (isClosed || _myUid != myUid) return;
      final blocks = BlockController.shared;
      if (!blocks.isBlocked(targetUid)) blocks.blockedUserIds.add(targetUid);

      // Lokal state güncelle
      isBlocked.value = true;
      isFriend.value = false;
      isPending.value = false;

      Get.snackbar(
        'Engellendi',
        'Kullanıcı engellendi; arkadaşlık ve bekleyen istekler kaldırıldı.',
        backgroundColor: const Color(0xFF1E2A22),
        colorText: const Color(0xFF2EED7B),
        snackPosition: SnackPosition.BOTTOM,
      );
    } catch (e) {
      Get.snackbar('Hata', e is SocialInteractionException ? e.message : 'Engelleme işlemi başarısız.',
          backgroundColor: Colors.red.shade700, colorText: Colors.white);
    } finally {
      isLoading.value = false;
    }
  }

  // ── Unblock User ────────────────────────────────────────────
  Future<void> unblockUser() async {
    final myUid = _myUid;
    if (myUid == null || myUid.isEmpty || targetUid.isEmpty) return;
    try {
      isLoading.value = true;
      await _db.collection('users').doc(myUid).update({
        'blockedUsers': FieldValue.arrayRemove([targetUid]),
      });
      if (isClosed || _myUid != myUid) return;
      BlockController.shared.blockedUserIds.remove(targetUid);
      isBlocked.value = false;
      Get.snackbar(
        'Engel Kaldırıldı',
        'Kullanıcının engeli kaldırıldı.',
        snackPosition: SnackPosition.BOTTOM,
      );
    } catch (e) {
      Get.snackbar('Hata', 'Engel kaldırılamadı: $e',
          backgroundColor: Colors.red.shade700, colorText: Colors.white);
    } finally {
      isLoading.value = false;
    }
  }

  // ── Send Follow Request ────────────────────────────────────
  Future<void> sendFollowRequest() async {
    final myUid = _myUid;
    if (myUid == null || myUid.isEmpty || targetUid.isEmpty || isLoading.value) {
      return;
    }
    isLoading.value = true;
    try {
      await SocialInteractions().requestFollow(targetUid);
      isPending.value = true;
    } catch (e) {
      Get.snackbar('Hata', e is SocialInteractionException ? e.message : 'Takip isteği gönderilemedi.');
    } finally {
      isLoading.value = false;
    }
  }

  // ── Cancel Follow Request ──────────────────────────────────
  Future<void> cancelFollowRequest() async {
    final myUid = _myUid;
    if (myUid == null || myUid.isEmpty || targetUid.isEmpty || isLoading.value) {
      return;
    }
    isLoading.value = true;
    try {
      await _db
          .collection('users')
          .doc(targetUid)
          .collection('followRequests')
          .doc(myUid)
          .delete();
      isPending.value = false;
    } catch (e) {
      Get.snackbar('Hata', 'İstek iptal edilemedi: $e');
    } finally {
      isLoading.value = false;
    }
  }

  // ── Remove Friend ───────────────────────────────────────────────
  Future<void> removeFriend() async {
    final myUid = _myUid;
    if (myUid == null || myUid.isEmpty || targetUid.isEmpty || isLoading.value) {
      return;
    }
    isLoading.value = true;
    try {
      final batch = _db.batch();

      // target.friends/{myUid}
      batch.delete(
        _db
            .collection('users')
            .doc(targetUid)
            .collection('friends')
            .doc(myUid),
      );

      // my.friends/{targetUid}
      batch.delete(
        _db
            .collection('users')
            .doc(myUid)
            .collection('friends')
            .doc(targetUid),
      );

      // NOT: followersCount / followingCount sayıçları Cloud Function'a bırakıldı.

      await batch.commit();
      isFriend.value = false;
    } catch (e) {
      Get.snackbar('Hata', 'Takipten çıkılamadı: $e');
    } finally {
      isLoading.value = false;
    }
  }

  // ── Accept Follow Request (gelen istek kabul) ──────────────────
  /// İki yönlü engel ve geçerli istek kontrolüyle arkadaşlığı kaydeder.
  Future<void> acceptFollowRequest(String fromUid) async {
    final myUid = _myUid;
    if (myUid == null || myUid.isEmpty || fromUid.isEmpty) return;
    
    try {
      await SocialInteractions().acceptFollow(fromUid);

      if (fromUid == targetUid) {
        isFriend.value = true;
      }
    } catch (e) {
      Get.snackbar(
        'Hata', 
        e is SocialInteractionException ? e.message : 'İstek kabul edilemedi.',
        backgroundColor: Colors.red.shade900,
        colorText: Colors.white,
      );
    }
  }

  // ── Update Profile ─────────────────────────────────────────
  Future<void> updateProfile({
    required String newName,
    required String newPosition,
    File? newAvatarFile,
  }) async {
    if (newName.trim().length > 100 || newPosition.trim().length > 40) {
      Get.snackbar('Hata', 'Ad en fazla 100, pozisyon en fazla 40 karakter olabilir.');
      return;
    }
    final user = _auth.currentUser;
    if (user == null || user.uid.isEmpty) return;

    final docRef = _db.collection('users').doc(user.uid);

    if (newName.trim().isNotEmpty) name.value = newName.trim();
    if (newPosition.trim().isNotEmpty) {
      position.value = newPosition.trim().toUpperCase();
      selectedPosition.value = newPosition.trim();
    }

    final Map<String, dynamic> updates = {};
    if (newName.trim().isNotEmpty) {
      updates['fullName'] = newName.trim();
      updates['name'] = newName.trim();
    }
    if (newPosition.trim().isNotEmpty) {
      updates['position'] = newPosition.trim().toUpperCase();
    }

    if (newAvatarFile != null) {
      isUploading.value = true;
      try {
        final downloadUrl = await uploadProfilePhoto(newAvatarFile, user.uid);
        if (isClosed || _auth.currentUser?.uid != user.uid) return;
        avatarFile.value = newAvatarFile;
        
        updates['avatarUrl'] = downloadUrl;
        updates['avatarData'] = FieldValue.delete();
        updates['avatarType'] = FieldValue.delete();
        
        avatarUrl.value = downloadUrl;
      } catch (e) {
        Get.snackbar('Fotoğraf yüklenemedi', e is ProfilePhotoException
            ? e.message : 'Fotoğraf yüklenemedi. Bağlantınızı ve hesap durumunuzu kontrol edin.');
      } finally {
        isUploading.value = false;
      }
    }

    if (updates.isNotEmpty) {
      await docRef.set(updates, SetOptions(merge: true));
    }
  }

  // ── Şifre Güncelleme ───────────────────────────────────────
  Future<void> updateUserPassword() async {
    final user = _auth.currentUser;
    if (user == null || user.email == null) return;

    if (!changePasswordFormKey.currentState!.validate()) {
      return;
    }

    try {
      isLoading.value = true;

      // 1. Mevcut şifre ile oturumu yenile (re-authenticate)
      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: currentPassword.value,
      );

      await user.reauthenticateWithCredential(credential);

      // 2. İşlem başarılıysa yeni şifreyi ayarla
      await user.updatePassword(newPassword.value);

      // Başarılı olursa alanları sıfırla
      currentPassword.value = '';
      newPassword.value = '';
      confirmPassword.value = '';

      // BottomSheet'i kapat
      Get.back();

      // Başarı mesajı
      Get.snackbar(
        'Başarılı',
        'Şifreniz başarıyla güncellendi.',
        backgroundColor: Colors.greenAccent.shade700,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
        margin: const EdgeInsets.all(16),
      );
    } on FirebaseAuthException catch (e) {
      // Re-auth başarısız olursa
      if (e.code == 'wrong-password' || e.code == 'invalid-credential') {
        Get.snackbar(
          'Hata',
          'Mevcut şifrenizi yanlış girdiniz.',
          backgroundColor: Colors.red.shade600,
          colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM,
          margin: const EdgeInsets.all(16),
        );
      } else {
        Get.snackbar(
          'Hata',
          'Şifre güncellenirken bir sorun oluştu: ${e.message}',
          backgroundColor: Colors.red.shade600,
          colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM,
          margin: const EdgeInsets.all(16),
        );
      }
    } catch (e) {
      Get.snackbar(
        'Hata',
        'Beklenmeyen bir hata oluştu: $e',
        backgroundColor: Colors.red.shade600,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
        margin: const EdgeInsets.all(16),
      );
    } finally {
      isLoading.value = false;
    }
  }

  // ── Hesabı Kalıcı Olarak Sil ───────────────────────────────
  Future<void> deleteUserAccount(String password) async {
    final user = _auth.currentUser;
    if (user == null || !isOwnProfile || isLoading.value) return;
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
