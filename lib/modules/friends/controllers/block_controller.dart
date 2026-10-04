import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';
import '../../../core/services/social_interactions.dart';

class BlockController extends GetxController {
  static BlockController get shared => Get.isRegistered<BlockController>()
      ? Get.find<BlockController>() : Get.put(BlockController());
  FirebaseFirestore get _firestore => FirebaseFirestore.instance;
  FirebaseAuth get _auth => FirebaseAuth.instance;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>?
  _blockedSubscription;

  // Engellenen kullanıcıların ID listesi
  var blockedUserIds = <String>[].obs;
  var isLoading = true.obs;
  final ready = false.obs;

  @override
  void onInit() {
    super.onInit();
    _auth.authStateChanges().listen((user) {
      if (user != null) {
        fetchBlockedUsers();
      } else {
        _blockedSubscription?.cancel();
        blockedUserIds.clear();
        ready.value = false;
      }
    });
  }

  // Engellenenleri getir
  Future<void> fetchBlockedUsers() async {
    await _blockedSubscription?.cancel();
    if (isClosed) return;
    ready.value = false;
    blockedUserIds.clear();
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;
    isLoading.value = true;
    _blockedSubscription = _firestore
        .collection('users')
        .doc(currentUser.uid)
        .snapshots()
        .listen(
          (doc) {
            if (isClosed || _auth.currentUser?.uid != currentUser.uid) return;
            blockedUserIds.assignAll(
              (doc.data()?['blockedUsers'] as List? ?? []).whereType<String>(),
            );
            isLoading.value = false;
            ready.value = true;
          },
          onError: (_) {
            if (isClosed) return;
            isLoading.value = false;
            Get.snackbar('Hata', 'Engellenen kullanıcılar yüklenemedi.');
          },
        );
  }

  @override
  void onClose() {
    _blockedSubscription?.cancel();
    super.onClose();
  }

  // Kullanıcıyı Engelle
  Future<void> blockUser(String targetUid) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null || targetUid == currentUser.uid) return;

    try {
      await SocialInteractions().block(targetUid);
      if (isClosed || _auth.currentUser?.uid != currentUser.uid) return;
      if (!blockedUserIds.contains(targetUid)) blockedUserIds.add(targetUid);
      Get.snackbar("Başarılı", "Kullanıcı engellendi.");
    } catch (e) {
      Get.snackbar("Hata", "Engelleme işlemi başarısız.");
    }
  }

  // Engeli Kaldır
  Future<void> unblockUser(String targetUid) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    try {
      await _firestore.collection('users').doc(currentUser.uid).update({
        'blockedUsers': FieldValue.arrayRemove([targetUid]),
      });
      if (isClosed || _auth.currentUser?.uid != currentUser.uid) return;
      blockedUserIds.remove(targetUid);
      Get.snackbar("Başarılı", "Engel kaldırıldı.");
    } catch (e) {
      Get.snackbar("Hata", "İşlem başarısız.");
    }
  }

  // Bu kullanıcı engelli mi? (Check fonksiyonu)
  bool isBlocked(String uid) => blockedUserIds.contains(uid);

  bool visible(String? uid) => ready.value && !blockedUserIds.contains(uid);
}
