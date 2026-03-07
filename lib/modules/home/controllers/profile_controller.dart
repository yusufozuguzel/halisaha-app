import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';

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

  // ── İstatistikler ──────────────────────────────────────────
  final RxInt matchesCount = 0.obs;
  final RxInt followersCount = 0.obs;
  final RxInt followingCount = 0.obs;

  // ── Upload durumu ──────────────────────────────────────────
  final RxBool isUploading = false.obs;

  // ── Firestore / Auth shortcuts ─────────────────────────────
  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  String? get _myUid => _auth.currentUser?.uid;

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
    for (final cancel in _subs) cancel();
    super.onClose();
  }

  // ── Realtime profile subscription ─────────────────────────
  void _subscribeToProfile() {
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
      // follower/following counters
      followersCount.value = (d['followersCount'] ?? 0) as int;
      followingCount.value = (d['followingCount'] ?? 0) as int;
    });
    _subs.add(sub.cancel);
  }

  // ── Stats: match count ─────────────────────────────────────
  void _subscribeToStats() {
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
    if (myUid == null) return;

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

  // ── Send Follow Request ────────────────────────────────────
  Future<void> sendFollowRequest() async {
    final myUid = _myUid;
    if (myUid == null || isLoading.value) return;
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
    if (myUid == null || isLoading.value) return;
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
    if (myUid == null || isLoading.value) return;
    isLoading.value = true;
    try {
      final batch = _db.batch();

      // target.followers/{myUid}
      batch.delete(
        _db
            .collection('users')
            .doc(targetUid)
            .collection('followers')
            .doc(myUid),
      );

      // my.following/{targetUid}
      batch.delete(
        _db
            .collection('users')
            .doc(myUid)
            .collection('following')
            .doc(targetUid),
      );

      // Sayaçları azalt
      batch.update(_db.collection('users').doc(targetUid), {
        'followersCount': FieldValue.increment(-1),
      });
      batch.update(_db.collection('users').doc(myUid), {
        'followingCount': FieldValue.increment(-1),
      });

      await batch.commit();
      isFollowing.value = false;
    } catch (e) {
      Get.snackbar('Hata', 'Takipten çıkılamadı: $e');
    } finally {
      isLoading.value = false;
    }
  }

  // ── Accept Follow Request (gelen istek kabul) ──────────────
  /// Bildirim ekranından veya profil sayfasından çağrılır.
  Future<void> acceptFollowRequest(String fromUid) async {
    final myUid = _myUid;
    if (myUid == null) return;
    try {
      final batch = _db.batch();

      // my.followers/{fromUid}
      batch.set(
        _db.collection('users').doc(myUid).collection('followers').doc(fromUid),
        {'uid': fromUid, 'since': FieldValue.serverTimestamp()},
      );

      // from.following/{myUid}
      batch.set(
        _db.collection('users').doc(fromUid).collection('following').doc(myUid),
        {'uid': myUid, 'since': FieldValue.serverTimestamp()},
      );

      // Sayaçları artır
      batch.update(_db.collection('users').doc(myUid), {
        'followersCount': FieldValue.increment(1),
      });
      batch.update(_db.collection('users').doc(fromUid), {
        'followingCount': FieldValue.increment(1),
      });

      // Bekleyen isteği sil
      batch.delete(
        _db
            .collection('users')
            .doc(myUid)
            .collection('followRequests')
            .doc(fromUid),
      );

      await batch.commit();
    } catch (e) {
      Get.snackbar('Hata', 'İstek kabul edilemedi: $e');
    }
  }

  // ── Update Profile ─────────────────────────────────────────
  Future<void> updateProfile({
    required String newName,
    required String newPosition,
    File? newAvatarFile,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return;

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
        final base64Str = await _compressAndEncode(newAvatarFile);
        updates['avatarType'] = 'base64';
        updates['avatarData'] = base64Str;
      } catch (e) {
        try {
          final bytes = await newAvatarFile.readAsBytes();
          updates['avatarType'] = 'base64';
          updates['avatarData'] = base64Encode(bytes);
        } catch (_) {}
      } finally {
        isUploading.value = false;
      }
    }

    if (updates.isNotEmpty) {
      await docRef.set(updates, SetOptions(merge: true));
    }
  }

  // ── Image compress helper (existing — untouched) ───────────
  Future<String> _compressAndEncode(File file) async {
    final Uint8List? compressed = await FlutterImageCompress.compressWithFile(
      file.absolute.path,
      minWidth: 300,
      minHeight: 300,
      quality: 70,
      format: CompressFormat.jpeg,
    );
    if (compressed != null && compressed.isNotEmpty) {
      return base64Encode(compressed);
    }
    final bytes = await file.readAsBytes();
    return base64Encode(bytes);
  }
}
