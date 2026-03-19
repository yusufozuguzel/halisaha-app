import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';

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
  final RxBool isFollowing = false.obs;
  final RxBool isRequestSent = false.obs;
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

  // ── Hesap Silme Durumu ─────────────────────────────────────
  final RxString deletePassword = "".obs;
  final RxBool isDeleteObscure = true.obs;

  // Using Form validation now, old manual computed values not needed but keeping for compatibility if used elsewhere
  bool get isLengthValid => newPassword.value.length >= 8;
  bool get isComplexValid => RegExp(r'[A-Z]').hasMatch(newPassword.value) && RegExp(r'[!@#\$%^&*(),.?":{}|<>]').hasMatch(newPassword.value);
  bool get isMatchValid => newPassword.value == confirmPassword.value;

  // ── Şifre Güncelle ──────────────────────────────────────────|──
  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  String? get _myUid => _auth.currentUser?.uid;

  bool get isGoogleUser =>
      FirebaseAuth.instance.currentUser?.providerData.any(
        (info) => info.providerId == 'google.com',
      ) ??
      false;

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
        .collection('following')
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
    final myDoc = await _db.collection('users').doc(myUid).get();
    if (myDoc.exists) {
      final blockedList = List<String>.from(myDoc.data()?['blockedUsers'] ?? []);
      isBlocked.value = blockedList.contains(targetUid);
    }

    // Engellenmişse takip durumunu kontrol etmeye gerek yok
    if (isBlocked.value) return;

    // Takip ediyor mu?
    final followerDoc = await _db
        .collection('users')
        .doc(targetUid)
        .collection('followers')
        .doc(myUid)
        .get();
    isFollowing.value = followerDoc.exists;

    // İstek gönderildi mi?
    if (!isFollowing.value) {
      final reqDoc = await _db
          .collection('users')
          .doc(targetUid)
          .collection('followRequests')
          .doc(myUid)
          .get();
      isRequestSent.value = reqDoc.exists;
    }
  }

  // ── Block User (Instagram-style) ──────────────────────────────
  Future<void> blockUser() async {
    final myUid = _myUid;
    if (myUid == null || myUid.isEmpty || targetUid.isEmpty) return;
    try {
      isLoading.value = true;
      final batch = _db.batch();

      // 1. Benım followersCount'u güncelle (āeger hedef beni takip ediyorsa)
      final targetFollowsMe = await _db
          .collection('users').doc(myUid).collection('followers').doc(targetUid).get();
      if (targetFollowsMe.exists) {
        batch.delete(_db.collection('users').doc(myUid).collection('followers').doc(targetUid));
        batch.delete(_db.collection('users').doc(targetUid).collection('following').doc(myUid));
        // NOT: followersCount / followingCount Cloud Function'a bırakıldı
      }

      // 2. Ben hedefi takip ediyorsam
      final iFollowTarget = await _db
          .collection('users').doc(targetUid).collection('followers').doc(myUid).get();
      if (iFollowTarget.exists) {
        batch.delete(_db.collection('users').doc(targetUid).collection('followers').doc(myUid));
        batch.delete(_db.collection('users').doc(myUid).collection('following').doc(targetUid));
        // NOT: followersCount / followingCount Cloud Function'a bırakıldı
      }

      // 3. Bekleyen followRequest'leri sil (her iki yön)
      batch.delete(_db.collection('users').doc(myUid).collection('followRequests').doc(targetUid));
      batch.delete(_db.collection('users').doc(targetUid).collection('followRequests').doc(myUid));

      // 4. Engelle: kendi dokümanıma hedefin UID'sini ekle
      // (Arkadaşlık / Following bağı zaten yukarıdaki 1. ve 2. adımlarda delete ile siliniyor)
      batch.update(_db.collection('users').doc(myUid), {
        'blockedUsers': FieldValue.arrayUnion([targetUid]),
      });

      await batch.commit();

      // Lokal state güncelle
      isBlocked.value = true;
      isFollowing.value = false;
      isRequestSent.value = false;

      Get.snackbar(
        'Engellendi',
        'Kullanıcı engellendi ve tüm bağlar koparıldı.',
        backgroundColor: const Color(0xFF1E2A22),
        colorText: const Color(0xFF2EED7B),
        snackPosition: SnackPosition.BOTTOM,
      );
    } catch (e) {
      Get.snackbar('Hata', 'Engelleme işlemi başarısız: $e',
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
      // followRequests alt koleksiyonuna yaz
      await _db
          .collection('users')
          .doc(targetUid)
          .collection('followRequests')
          .doc(myUid)
          .set({
            'from': myUid,
            'status': 'pending',
            'createdAt': FieldValue.serverTimestamp(),
          });
      isRequestSent.value = true;

      // ── Düzeltme: bildirimi atan KENDİ adımızı Firestore'dan al ──
      final myDoc = await _db.collection('users').doc(myUid).get();
      final myName =
          myDoc.data()?['fullName'] ?? myDoc.data()?['name'] ?? 'Biri';

      // Karşı tarafa tam payload'lı bildirim gönder
      await _db
          .collection('users')
          .doc(targetUid)
          .collection('notifications')
          .add({
            'title': 'Yeni Takip İsteği 👥',
            'message': '$myName sana takip isteği gönderdi.',
            'type': 'follow_request',
            'senderUid': myUid,
            'senderName': myName,
            'createdAt': FieldValue.serverTimestamp(),
            'status': 'pending',
          });
    } catch (e) {
      Get.snackbar('Hata', 'Takip isteği gönderilemedi: $e');
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
      isRequestSent.value = false;
    } catch (e) {
      Get.snackbar('Hata', 'İstek iptal edilemedi: $e');
    } finally {
      isLoading.value = false;
    }
  }

  // ── Unfollow ───────────────────────────────────────────────
  Future<void> unfollow() async {
    final myUid = _myUid;
    if (myUid == null || myUid.isEmpty || targetUid.isEmpty || isLoading.value) {
      return;
    }
    isLoading.value = true;
    try {
      final batch = _db.batch();

      // target.followers/{myUid} — hedefin alt koleksiyonu (OK)
      batch.delete(
        _db
            .collection('users')
            .doc(targetUid)
            .collection('followers')
            .doc(myUid),
      );

      // my.following/{targetUid} — benim alt koleksiyonum (OK)
      batch.delete(
        _db
            .collection('users')
            .doc(myUid)
            .collection('following')
            .doc(targetUid),
      );

      // NOT: followersCount / followingCount sayıçları Cloud Function'a bırakıldı.

      await batch.commit();
      isFollowing.value = false;
    } catch (e) {
      Get.snackbar('Hata', 'Takipten çıkılamadı: $e');
    } finally {
      isLoading.value = false;
    }
  }

  // ── Accept Follow Request (gelen istek kabul) ──────────────────
  /// SADECE SADECE ŞU 3 İŞLEMİ YAPAR:
  /// 1. users/{currentUser}/followers/{fromUid} set
  /// 2. users/{fromUid}/following/{currentUser} set
  /// 3. users/{currentUser}/followRequests/{fromUid} delete
  Future<void> acceptFollowRequest(String fromUid) async {
    final myUid = _myUid;
    if (myUid == null || myUid.isEmpty || fromUid.isEmpty) return;
    
    try {
      final batch = _db.batch();

      // 1. users/{currentUser}/followers/{senderUid} dökümanını set et
      batch.set(
        _db.collection('users').doc(myUid).collection('followers').doc(fromUid),
        {'uid': fromUid, 'since': FieldValue.serverTimestamp()},
      );

      // 2. users/{senderUid}/following/{currentUser} dökümanını set et
      batch.set(
        _db.collection('users').doc(fromUid).collection('following').doc(myUid),
        {'uid': myUid, 'since': FieldValue.serverTimestamp()},
      );

      // 3. users/{currentUser}/followRequests/{senderUid} dökümanını delete et.
      batch.delete(
        _db.collection('users').doc(myUid).collection('followRequests').doc(fromUid),
      );

      await batch.commit();

      if (fromUid == targetUid) {
        isFollowing.value = true;
      }
    } catch (e) {
      print('FIREBASE KABUL ETME HATASI: $e');
      Get.snackbar(
        'Hata', 
        'İstek kabul edilemedi, yetki reddedildi: $e',
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
      avatarFile.value = newAvatarFile;
      try {
        final storageRef = FirebaseStorage.instance
            .ref()
            .child('profile_images/${user.uid}.jpg');
            
        await storageRef.putFile(newAvatarFile);
        final downloadUrl = await storageRef.getDownloadURL();
        
        updates['avatarUrl'] = downloadUrl;
        updates['avatarData'] = FieldValue.delete();
        updates['avatarType'] = FieldValue.delete();
        
        avatarUrl.value = downloadUrl;
      } catch (e) {
        Get.snackbar('Hata', 'Fotoğraf yüklenemedi: $e');
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
  Future<void> deleteUserAccount() async {
    final user = _auth.currentUser;
    if (user == null) return;

    if (!isGoogleUser && deletePassword.value.isEmpty) {
      Get.snackbar(
        'Uyarı',
        'Lütfen mevcut şifrenizi girin.',
        backgroundColor: Colors.orange.shade600,
        colorText: Colors.white,
      );
      return;
    }

    try {
      isLoading.value = true;

      // 1. Re-authenticate user
      if (isGoogleUser) {
        final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
        if (googleUser == null) {
          isLoading.value = false;
          return;
        }

        final GoogleSignInAuthentication googleAuth =
            await googleUser.authentication;

        final AuthCredential credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );

        await user.reauthenticateWithCredential(credential);
      } else {
        if (user.email == null) return;
        final credential = EmailAuthProvider.credential(
          email: user.email!,
          password: deletePassword.value,
        );
        await user.reauthenticateWithCredential(credential);
      }

      // 2. Kullanıcının kurduğu tüm maçları sil (createdBy == uid)
      final matchesSnap = await _db
          .collection('matches')
          .where('createdBy', isEqualTo: user.uid)
          .get();

      if (matchesSnap.docs.isNotEmpty) {
        final matchBatch = _db.batch();
        for (final doc in matchesSnap.docs) {
          matchBatch.delete(doc.reference);
        }
        await matchBatch.commit();
      }

      // 3. Firebase Storage'dan profil fotoğrafını sil
      try {
        final storageRef = FirebaseStorage.instance
            .ref()
            .child('profile_images/${user.uid}.jpg');
        await storageRef.delete();
      } catch (_) {
        // Fotoğraf yoksa sessizce geç
      }

      // 4. Firestore'daki kullanıcı belgesini sil
      await _db.collection('users').doc(user.uid).delete();

      // 5. Firebase Auth'dan hesabı tamamen sil
      await user.delete();

      Get.snackbar(
        'Hesap Silindi',
        'Hesabınız ve tüm verileriniz kalıcı olarak silinmiştir.',
        backgroundColor: Colors.greenAccent.shade700,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
        margin: const EdgeInsets.all(16),
      );

      Get.offAllNamed('/auth');
    } on FirebaseAuthException catch (e) {
      // Re-auth başarısız olursa
      if (e.code == 'wrong-password' || e.code == 'invalid-credential') {
        Get.snackbar(
          'Hata',
          'Hatalı Şifre',
          backgroundColor: Colors.red.shade600,
          colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM,
          margin: const EdgeInsets.all(16),
        );
      } else {
        Get.snackbar(
          'Hata',
          'Hesap silinirken bir sorun oluştu: ${e.message}',
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
}
