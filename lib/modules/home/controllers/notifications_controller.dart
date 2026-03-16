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
        .collection('following')
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

  /// Tek bir bildirimi sil
  Future<void> deleteNotification(String docId) async {
    final uid = _uid;
    if (uid == null) return;
    await _firestore
        .collection('users')
        .doc(uid)
        .collection('notifications')
        .doc(docId)
        .delete();
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
      final batch = db.batch();

      // 1. users/{currentUser}/followers/{senderUid} dökümanını set et.
      batch.set(
        db.collection('users').doc(myUid).collection('followers').doc(senderUid),
        {'uid': senderUid, 'since': FieldValue.serverTimestamp()},
      );

      // 2. users/{senderUid}/following/{currentUser} dökümanını set et.
      batch.set(
        db.collection('users').doc(senderUid).collection('following').doc(myUid),
        {'uid': myUid, 'since': FieldValue.serverTimestamp()},
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
          'message': '$myName sana takip isteği gönderdi.',
          'type': 'follow_request',
          'senderUid': myUid,
          'senderName': myName,
          'createdAt': FieldValue.serverTimestamp(),
          'status': 'pending',
        });
  }
}
