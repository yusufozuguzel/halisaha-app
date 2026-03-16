import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';

class BlockController extends GetxController {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Engellenen kullanıcıların ID listesi
  var blockedUserIds = <String>[].obs;
  var isLoading = false.obs;

  @override
  void onInit() {
    super.onInit();
    fetchBlockedUsers();
  }

  // Engellenenleri getir
  Future<void> fetchBlockedUsers() async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    try {
      isLoading.value = true;
      DocumentSnapshot userDoc = await _firestore
          .collection('users')
          .doc(currentUser.uid)
          .get();

      if (userDoc.exists && userDoc.data() != null) {
        Map<String, dynamic> data = userDoc.data() as Map<String, dynamic>;
        blockedUserIds.value = List<String>.from(data['blockedUsers'] ?? []);
      }
    } catch (e) {
      print("Engellenenler çekilirken hata: $e");
    } finally {
      isLoading.value = false;
    }
  }

  // Kullanıcıyı Engelle
  Future<void> blockUser(String targetUid) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null || targetUid == currentUser.uid) return;

    try {
      await _firestore.collection('users').doc(currentUser.uid).update({
        'blockedUsers': FieldValue.arrayUnion([targetUid]),
      });

      blockedUserIds.add(targetUid);
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

      blockedUserIds.remove(targetUid);
      Get.snackbar("Başarılı", "Engel kaldırıldı.");
    } catch (e) {
      Get.snackbar("Hata", "İşlem başarısız.");
    }
  }

  // Bu kullanıcı engelli mi? (Check fonksiyonu)
  bool isBlocked(String uid) => blockedUserIds.contains(uid);
}
