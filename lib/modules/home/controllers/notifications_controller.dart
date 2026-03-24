import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class NotificationsController extends GetxController {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? get _uid => _auth.currentUser?.uid;

  // Takip durumunu tutan harita (TargetUID -> isFollowing)
  final RxMap<String, RxBool> followingStatus = <String, RxBool>{}.obs;

  // Yeni Eklenecek: Maç davetleri için
  final RxList<QueryDocumentSnapshot> matchInvites = <QueryDocumentSnapshot>[].obs;

  // Yeni Özellikler: Geri alma, okunmamış sayacı
  final RxInt unreadCount = 0.obs;
  final RxList<String> hiddenNotificationIds = <String>[].obs;

  @override
  void onInit() {
    super.onInit();
    _listenToMatchInvites();
    _listenToUnreadNotifications();
  }

  void _listenToUnreadNotifications() {
    final uid = _uid;
    if (uid == null) return;

    _firestore
        .collection('users')
        .doc(uid)
        .collection('notifications')
        .where('isRead', isEqualTo: false)
        .snapshots()
        .listen((snapshot) {
      unreadCount.value = snapshot.docs.length;
    });
  }

  void _listenToMatchInvites() {
    final uid = _uid;
    if (uid == null) return;
    
    _firestore
        .collection('notifications')
        .where('receiverId', isEqualTo: uid)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .listen((snapshot) {
      matchInvites.value = snapshot.docs;
    });
  }

  /// Belirtilen kullanıcıyı takip edip etmediğimizi kontrol eder
  void checkIfFollowing(String targetUid) {
    if (followingStatus.containsKey(targetUid)) {
      return; // Daha önce kontrol edildiyse tekrar etme
    }

    final myUid = _uid;
    if (myUid == null) return;

    // Default false olarak başlat
    followingStatus[targetUid] = false.obs;

    _firestore
        .collection('users')
        .doc(myUid)
        .collection('friends')
        .doc(targetUid)
        .get()
        .then((doc) {
          followingStatus[targetUid]!.value = doc.exists;
        });
  }

  /// Bildirimleri anlık dinleyen stream (en yeni en üstte)
  Stream<QuerySnapshot> get notificationsStream {
    final uid = _uid;
    if (uid == null) return const Stream.empty();
    return _firestore
        .collection('users')
        .doc(uid)
        .collection('notifications')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  /// Bildirimleri okundu olarak işaretle
  Future<void> markAllAsRead() async {
    final uid = _uid;
    if (uid == null) return;

    final snapshot = await _firestore
        .collection('users')
        .doc(uid)
        .collection('notifications')
        .where('isRead', isEqualTo: false)
        .get();

    if (snapshot.docs.isEmpty) return;

    final batch = _firestore.batch();
    for (var doc in snapshot.docs) {
      batch.update(doc.reference, {'isRead': true});
    }
    await batch.commit();
  }

  /// Tek bir bildirimi sil (Undo destekli)
  Future<void> deleteNotification(String docId) async {
    final uid = _uid;
    if (uid == null) return;

    // 1) UI'dan gizlemek için ID'yi listeye ekle
    hiddenNotificationIds.add(docId);

    bool isUndone = false;

    // 2) Kullanıcıya bildiri (Snackbar) çıkar
    Get.snackbar(
      'Bildirim silindi.',
      '',
      snackPosition: SnackPosition.BOTTOM,
      duration: const Duration(seconds: 3),
      backgroundColor: Colors.grey.shade900,
      colorText: Colors.white,
      mainButton: TextButton(
        onPressed: () {
          isUndone = true;
          hiddenNotificationIds.remove(docId);
          Get.back(); // Snackbar'ı kapat
        },
        child: const Text(
          'Geri Al',
          style: TextStyle(
            color: Color(0xFF2EED7B),
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );

    // 3) 3 saniye sonra geri alınmadıysa gerçek silme işlemini yap
    await Future.delayed(const Duration(seconds: 3));

    if (!isUndone) {
      await _firestore
          .collection('users')
          .doc(uid)
          .collection('notifications')
          .doc(docId)
          .delete();
      hiddenNotificationIds.remove(docId);
    }
  }

  /// Tüm bildirimleri toplu sil (batch)
  Future<void> clearAllNotifications() async {
    final uid = _uid;
    if (uid == null) return;
    final snapshot = await _firestore
        .collection('users')
        .doc(uid)
        .collection('notifications')
        .get();
    final batch = _firestore.batch();
    for (var doc in snapshot.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }

  /// Yeni bildirim ekle — kendi kullanıcının bildirim kutusuna
  Future<void> addNotification({
    required String title,
    required String message,
  }) async {
    final uid = _uid;
    if (uid == null) return;
    await _firestore
        .collection('users')
        .doc(uid)
        .collection('notifications')
        .add({
          'title': title,
          'message': message,
          'isRead': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
  }

  /// Başka bir kullanıcıya bildirim gönder (takip isteği vb.)
  Future<void> addNotificationToUser({
    required String targetUid,
    required String title,
    required String message,
  }) async {
    await _firestore
        .collection('users')
        .doc(targetUid)
        .collection('notifications')
        .add({
          'title': title,
          'message': message,
          'isRead': false,
          'createdAt': FieldValue.serverTimestamp(),
          'fromUid': _uid ?? '',
        });
  }

  // ── FOLLOW REQUEST — Accept ────────────────────────────────────────────

  /// SADECE SADECE ŞU 4 İŞLEMİ YAPAR:
  /// 1. users/{currentUser}/followers/{senderUid} set
  /// 2. users/{senderUid}/following/{currentUser} set
  /// 3. users/{currentUser}/followRequests/{senderUid} delete
  /// 4. users/{currentUser}/notifications/{notificationDocId} update
  Future<void> acceptFollowRequest({
    required String senderUid,
    required String notificationDocId,
  }) async {
    final myUid = _uid;
    if (myUid == null) return;

    final db = _firestore;
    try {
      final myDoc = await db.collection('users').doc(myUid).get();
      final senderDoc = await db.collection('users').doc(senderUid).get();

      final myData = myDoc.data() ?? {};
      final senderData = senderDoc.data() ?? {};

      final batch = db.batch();

      // B'nin (Kabul eden) friends koleksiyonuna A'yı ekle
      batch.set(
        db.collection('users').doc(myUid).collection('friends').doc(senderUid),
        {
          'uid': senderUid,
          'fullName': senderData['fullName'] ?? senderData['name'] ?? '',
          'avatarUrl': senderData['avatarUrl'] ?? '',
          'avatarData': senderData['avatarData'] ?? '0',
          'position': senderData['position'] ?? '',
          'since': FieldValue.serverTimestamp()
        },
      );

      // A'nın (İstek gönderen) friends koleksiyonuna B'yi ekle
      batch.set(
        db.collection('users').doc(senderUid).collection('friends').doc(myUid),
        {
          'uid': myUid,
          'fullName': myData['fullName'] ?? myData['name'] ?? '',
          'avatarUrl': myData['avatarUrl'] ?? '',
          'avatarData': myData['avatarData'] ?? '0',
          'position': myData['position'] ?? '',
          'since': FieldValue.serverTimestamp()
        },
      );

      // 3. users/{currentUser}/followRequests/{senderUid} dökümanını delete et.
      batch.delete(
        db.collection('users').doc(myUid).collection('followRequests').doc(senderUid),
      );

      // 4. Mevcut kullanıcının users/{currentUser}/notifications/{notificationId} dökümanını update et.
      batch.update(
        db.collection('users').doc(myUid).collection('notifications').doc(notificationDocId),
        {'status': 'accepted'},
      );

      await batch.commit();
      
      checkIfFollowing(senderUid); // UI'ı güncelle
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

  // ── FOLLOW REQUEST — Reject ──────────────────────────────────────────────────

  /// Takip isteğini reddet:
  /// - followRequests kaydını sil
  /// - Bildirim kartını 'rejected' olarak işaretle
  Future<void> rejectFollowRequest({
    required String senderUid,
    required String notificationDocId,
  }) async {
    final myUid = _uid;
    if (myUid == null) return;

    final db = _firestore;
    final batch = db.batch();

    batch.delete(
      db
          .collection('users')
          .doc(myUid)
          .collection('followRequests')
          .doc(senderUid),
    );

    batch.update(
      db
          .collection('users')
          .doc(myUid)
          .collection('notifications')
          .doc(notificationDocId),
      {'status': 'rejected'},
    );

    await batch.commit();
  }

  // ── FOLLOW BACK ──────────────────────────────────────────────────────────────

  /// Karşı tarafa geri takip isteği gönder.
  /// Aynı sendFollowRequest mantığı — bildirim 'follow_request' payload'ı ile.
  Future<void> sendFollowBackRequest({required String targetUid}) async {
    final myUid = _uid;
    if (myUid == null) return;

    final db = _firestore;

    // followRequests'e yaz
    await db
        .collection('users')
        .doc(targetUid)
        .collection('followRequests')
        .doc(myUid)
        .set({
          'from': myUid,
          'status': 'pending',
          'createdAt': FieldValue.serverTimestamp(),
        });

    // Kendi adımızı Firestore'dan al
    final myDoc = await db.collection('users').doc(myUid).get();
    final myName = myDoc.data()?['fullName'] ?? myDoc.data()?['name'] ?? 'Biri';

    // Karşı tarafa bildirim gönder
    await db
        .collection('users')
        .doc(targetUid)
        .collection('notifications')
        .add({
          'title': 'Yeni Takip İsteği 👥',
          'message': '$myName seninle arkadaş olmak istiyor.',
          'type': 'follow_request',
          'senderUid': myUid,
          'senderName': myName,
          'createdAt': FieldValue.serverTimestamp(),
          'status': 'pending',
        });
  }

  // ── MATCH INVITES ────────────────────────────────────────────────────────────

  Future<void> acceptInvite(String notificationId, String matchId, String positionId) async {
    final myUid = _uid;
    if (myUid == null) return;

    final batch = _firestore.batch();
    
    // 1. Update notification status to accepted
    batch.update(
      _firestore.collection('notifications').doc(notificationId),
      {'status': 'accepted'}
    );

    // 2. Update matches doc
    final matchRef = _firestore.collection('matches').doc(matchId);
    batch.update(matchRef, {
      'currentPlayers': FieldValue.arrayUnion([myUid]),
      'positions.$positionId': myUid,
      'pendingPositions.$positionId': FieldValue.delete(),
    });

    try {
      await batch.commit();
      Get.snackbar(
        'Başarılı', 
        'Maç davetini kabul ettin!', 
        backgroundColor: const Color(0xFF1E2A22), 
        colorText: const Color(0xFF2EED7B),
        snackPosition: SnackPosition.BOTTOM
      );
    } catch(e) {
      Get.snackbar('Hata', 'İşlem başarısız: $e', backgroundColor: Colors.red.shade900, colorText: Colors.white);
    }
  }

  Future<void> rejectInvite(String notificationId, String matchId, String positionId) async {
    final myUid = _uid;
    if (myUid == null) return;
    
    try {
      final matchDoc = await _firestore.collection('matches').doc(matchId).get();
      final creatorId = matchDoc.data()?['createdBy'] as String?;

      final batch = _firestore.batch();
      
      // 1. Delete notification
      batch.delete(_firestore.collection('notifications').doc(notificationId));

      // 2. Update matches doc (remove pending position and from invitedPlayers list)
      final matchRef = _firestore.collection('matches').doc(matchId);
      batch.update(matchRef, {
        'pendingPositions.$positionId': FieldValue.delete(),
        'invitedPlayers': FieldValue.arrayRemove([myUid]),
      });

      // 3. Bildirimi kurucuya ilet
      if (creatorId != null && creatorId != myUid) {
        final notifRef = _firestore.collection('notifications').doc();
        batch.set(notifRef, {
          'receiverId': creatorId,
          'senderId': myUid,
          'type': 'invite_rejected',
          'matchId': matchId,
          'createdAt': FieldValue.serverTimestamp(),
          'status': 'unread'
        });
      }

      await batch.commit();
      Get.snackbar('Bilgi', 'Maç daveti reddedildi.', backgroundColor: Colors.black87, colorText: Colors.white, snackPosition: SnackPosition.BOTTOM);
    } catch(e) {
      Get.snackbar('Hata', 'İşlem başarısız: $e', backgroundColor: Colors.red.shade900, colorText: Colors.white);
    }
  }
}
