import '../../../core/services/match_participation.dart';
import 'dart:async';
import '../../friends/controllers/block_controller.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/services/social_interactions.dart';

class NotificationsController extends GetxController {
  final _blocks = BlockController.shared;
  final List<StreamSubscription> _subscriptions = [];
  final RxList<QueryDocumentSnapshot> _unread = <QueryDocumentSnapshot>[].obs;
  final RxList<QueryDocumentSnapshot> _allInvites = <QueryDocumentSnapshot>[].obs;
  bool visibleNotification(QueryDocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return _blocks.visible((data['senderUid'] ?? data['senderId'] ?? data['fromUid'] ?? data['from']) as String?);
  }
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? get _uid => _auth.currentUser?.uid;

  // Takip durumunu tutan harita (TargetUID -> isFollowing)
  final RxMap<String, RxBool> followingStatus = <String, RxBool>{}.obs;

  // Yeni Eklenecek: Maç davetleri için
  List<QueryDocumentSnapshot> get matchInvites => _allInvites.where(visibleNotification).toList();

  // Yeni Özellikler: Geri alma, okunmamış sayacı
  int get unreadCount => _unread.where(visibleNotification).length;
  final RxList<String> hiddenNotificationIds = <String>[].obs;

  @override
  void onInit() {
    super.onInit();
    _auth.authStateChanges().listen((user) {
      for (final subscription in _subscriptions) { subscription.cancel(); }
      _subscriptions.clear();
      _unread.clear();
      _allInvites.clear();
      
      if (user != null) {
        _listenToMatchInvites();
        _listenToUnreadNotifications();
      }
    });
  }

  @override
  void onClose() {
    for (final subscription in _subscriptions) { subscription.cancel(); }
    super.onClose();
  }

  void _listenToUnreadNotifications() {
    final uid = _uid;
    if (uid == null) return;

    _subscriptions.add(_firestore
        .collection('users')
        .doc(uid)
        .collection('notifications')
        .where('isRead', isEqualTo: false)
        .snapshots()
        .listen((snapshot) {
      if (!isClosed) _unread.assignAll(snapshot.docs);
    }, onError: (_) { if (!isClosed) _unread.clear(); }));
  }

  void _listenToMatchInvites() {
    final uid = _uid;
    if (uid == null) return;
    
    _subscriptions.add(_firestore
        .collection('notifications')
        .where('receiverId', isEqualTo: uid)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .listen((snapshot) {
      if (!isClosed) _allInvites.assignAll(snapshot.docs);
    }, onError: (_) { if (!isClosed) _allInvites.clear(); }));
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
      backgroundColor: Colors.grey.shade800,
      colorText: Colors.white,
      margin: const EdgeInsets.all(12),
      borderRadius: 8,
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

    if (snapshot.docs.isEmpty) return;

    // 1) UI'dan gizlemek için ID'leri yedekle ve ekle
    final idsToHide = snapshot.docs.map((d) => d.id).toList();
    hiddenNotificationIds.addAll(idsToHide);

    bool isUndone = false;

    // 2) Kullanıcıya bildiri (Snackbar) çıkar
    Get.snackbar(
      'Tüm bildirimler silindi',
      '',
      snackPosition: SnackPosition.BOTTOM,
      duration: const Duration(seconds: 3),
      backgroundColor: Colors.grey.shade800,
      colorText: Colors.white,
      margin: const EdgeInsets.all(12),
      borderRadius: 8,
      mainButton: TextButton(
        onPressed: () {
          isUndone = true;
          hiddenNotificationIds.removeWhere((id) => idsToHide.contains(id));
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

    // 3) 3 saniye bekle
    await Future.delayed(const Duration(seconds: 3));

    // 4) Geri alınmadıysa batch ile tamamen sil
    if (!isUndone) {
      final batch = _firestore.batch();
      for (var doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();

      // Temizlenen id'leri hidden listesinden çıkarabiliriz
      hiddenNotificationIds.removeWhere((id) => idsToHide.contains(id));
    }
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

  /// Geçerli istek ve iki yönlü engel kontrolüyle arkadaşlığı ve bildirimi günceller.
  Future<void> acceptFollowRequest({
    required String senderUid,
    required String notificationDocId,
  }) async {
    final myUid = _uid;
    if (myUid == null) return;

    try {
      await SocialInteractions().acceptFollow(senderUid,
          notificationId: notificationDocId);
      followingStatus[senderUid] = true.obs;
    } catch (e) {
      Get.snackbar('Hata', e is SocialInteractionException
          ? e.message : 'İstek kabul edilemedi.');
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
    try {
      await SocialInteractions().requestFollow(targetUid);
    } catch (e) {
      Get.snackbar('Hata', e is SocialInteractionException
          ? e.message : 'İstek gönderilemedi.');
    }
  }

  // ── MATCH INVITES ────────────────────────────────────────────────────────────

  Future<void> acceptInvite(String notificationId, String matchId, String positionId) async {
    try {
      await MatchParticipation().respond(matchId, notificationId, positionId, accept: true);
      Get.snackbar('Başarılı', 'Maç davetini kabul ettiniz.');
    } catch (e) {
      Get.snackbar('İşlem tamamlanamadı', e is MatchActionException ? e.message : 'Lütfen tekrar deneyin.');
    }
  }

  Future<void> rejectInvite(String notificationId, String matchId, String positionId) async {
    try {
      await MatchParticipation().respond(matchId, notificationId, positionId, accept: false);
      Get.snackbar('Bilgi', 'Maç daveti reddedildi.');
    } catch (e) {
      Get.snackbar('İşlem tamamlanamadı', e is MatchActionException ? e.message : 'Lütfen tekrar deneyin.');
    }
  }
}
