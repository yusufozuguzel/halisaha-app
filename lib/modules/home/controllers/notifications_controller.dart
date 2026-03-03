import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';

class NotificationsController extends GetxController {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? get _uid => _auth.currentUser?.uid;

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

  /// Yeni bildirim ekle (maç oluşturma, katılma vb. yerlerden çağrılabilir)
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
}
