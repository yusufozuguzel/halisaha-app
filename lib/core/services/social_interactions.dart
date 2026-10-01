import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SocialInteractionException implements Exception {
  const SocialInteractionException(this.message);
  final String message;
  @override
  String toString() => message;
}

// Client transactions prevent stale screens and concurrent block changes from
// bypassing checks in this app. Production rules must enforce the same policy.
abstract interface class SocialTransaction {
  Future<Map<String, dynamic>?> read(String path);
  void set(String path, Map<String, dynamic> data);
  void update(String path, Map<String, dynamic> data);
  void delete(String path);
}

abstract interface class SocialStore {
  Future<void> run(Future<void> Function(SocialTransaction) action);
  String newId();
}

class FirestoreSocialStore implements SocialStore {
  FirestoreSocialStore(this.db);
  final FirebaseFirestore db;
  @override
  String newId() => db.collection('users').doc().id;
  @override
  Future<void> run(Future<void> Function(SocialTransaction) action) =>
      db.runTransaction((tx) => action(_FirestoreSocialTransaction(db, tx)));
}

class _FirestoreSocialTransaction implements SocialTransaction {
  _FirestoreSocialTransaction(this.db, this.tx);
  final FirebaseFirestore db;
  final Transaction tx;
  @override
  Future<Map<String, dynamic>?> read(String path) async =>
      (await tx.get(db.doc(path))).data();
  @override
  void set(String path, Map<String, dynamic> data) =>
      tx.set(db.doc(path), data);
  @override
  void update(String path, Map<String, dynamic> data) =>
      tx.update(db.doc(path), data);
  @override
  void delete(String path) => tx.delete(db.doc(path));
}

class SocialInteractions {
  SocialInteractions({SocialStore? store, String? Function()? currentUid})
    : _store = store ?? FirestoreSocialStore(FirebaseFirestore.instance),
      _currentUid =
          currentUid ?? (() => FirebaseAuth.instance.currentUser?.uid);
  final SocialStore _store;
  final String? Function() _currentUid;

  String _actor(String target) {
    final uid = _currentUid();
    if (uid == null || uid.isEmpty) {
      throw const SocialInteractionException('Lütfen yeniden giriş yapın.');
    }
    if (target.isEmpty ||
        target.length > 128 ||
        target.contains('/') ||
        target == uid) {
      throw const SocialInteractionException('Geçersiz kullanıcı.');
    }
    return uid;
  }

  Future<List<Map<String, dynamic>>> _pair(
    SocialTransaction tx,
    String uid,
    String target,
  ) async {
    final me = await tx.read('users/$uid');
    final other = await tx.read('users/$target');
    if (me == null || other == null) {
      throw const SocialInteractionException('Kullanıcı bulunamadı.');
    }
    if (_blocked(me, target) || _blocked(other, uid)) {
      throw const SocialInteractionException(
        'Bu kullanıcıyla işlem yapılamıyor.',
      );
    }
    return [me, other];
  }

  bool _blocked(Map<String, dynamic> data, String uid) {
    final values = data['blockedUsers'];
    // Malformed legacy data must not silently permit an interaction.
    if (values != null && values is! List) {
      throw const SocialInteractionException(
        'Kullanıcı bilgileri doğrulanamadı.',
      );
    }
    return values is List && values.contains(uid);
  }

  Future<void> requestFollow(String target) async {
    final uid = _actor(target);
    final notification = _store.newId();
    await _store.run((tx) async {
      final pair = await _pair(tx, uid, target);
      final path = 'users/$target/followRequests/$uid';
      final existing = await tx.read(path);
      final friend = await tx.read('users/$uid/friends/$target');
      if (friend != null) {
        throw const SocialInteractionException('Zaten arkadaşsınız.');
      }
      if (existing != null) return;
      final name = pair[0]['fullName'] ?? pair[0]['name'] ?? 'Bir oyuncu';
      tx.set(path, {
        'from': uid,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });
      tx.set('users/$target/notifications/$notification', {
        'title': 'Yeni Takip İsteği 👥',
        'message': '$name seninle arkadaş olmak istiyor.',
        'type': 'follow_request',
        'senderUid': uid,
        'senderName': name,
        'isRead': false,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Future<void> acceptFollow(String sender, {String? notificationId}) async {
    final uid = _actor(sender);
    if (notificationId != null &&
        (notificationId.isEmpty || notificationId.contains('/'))) {
      throw const SocialInteractionException('Geçersiz bildirim.');
    }
    await _store.run((tx) async {
      final pair = await _pair(tx, uid, sender);
      final path = 'users/$uid/followRequests/$sender';
      final request = await tx.read(path);
      if (request == null ||
          request['from'] != sender ||
          request['status'] != 'pending') {
        throw const SocialInteractionException('Bu istek artık geçerli değil.');
      }
      final notificationPath = 'users/$uid/notifications/$notificationId';
      if (notificationId != null) {
        final notice = await tx.read(notificationPath);
        if (notice == null ||
            notice['type'] != 'follow_request' ||
            notice['senderUid'] != sender) {
          throw const SocialInteractionException(
            'Bu bildirim artık geçerli değil.',
          );
        }
      }
      tx.set('users/$uid/friends/$sender', _friend(sender, pair[1]));
      tx.set('users/$sender/friends/$uid', _friend(uid, pair[0]));
      tx.delete(path);
      // A crossed request must not remain actionable after becoming friends.
      tx.delete('users/$sender/followRequests/$uid');
      if (notificationId != null) {
        tx.update(notificationPath, {'status': 'accepted', 'isRead': true});
      }
    });
  }

  Map<String, dynamic> _friend(String uid, Map<String, dynamic> data) => {
    'uid': uid,
    'fullName': data['fullName'] ?? data['name'] ?? '',
    'avatarUrl': data['avatarUrl'] ?? '',
    'avatarData': data['avatarData'] ?? '0',
    'position': data['position'] ?? '',
    'since': FieldValue.serverTimestamp(),
  };

  Future<void> block(String target) async {
    final uid = _actor(target);
    await _store.run((tx) async {
      if (await tx.read('users/$uid') == null) {
        throw const SocialInteractionException('Profil bulunamadı.');
      }
      tx.update('users/$uid', {
        'blockedUsers': FieldValue.arrayUnion([target]),
      });
      for (final group in ['friends', 'followRequests']) {
        tx.delete('users/$uid/$group/$target');
        tx.delete('users/$target/$group/$uid');
      }
    });
  }

  Future<void> invite(String target, String matchId) async {
    final uid = _actor(target);
    if (matchId.isEmpty || matchId.length > 128 || matchId.contains('/')) {
      throw const SocialInteractionException('Geçersiz maç.');
    }
    // Encoded tuple is collision-free and stays within Firestore ID limits.
    final id = base64Url.encode(utf8.encode(jsonEncode([matchId, uid])));
    await _store.run((tx) async {
      await _pair(tx, uid, target);
      final match = await tx.read('matches/$matchId');
      if (match == null || match['createdBy'] != uid) {
        throw const SocialInteractionException(
          'Bu maça davet gönderemezsiniz.',
        );
      }
      final date = match['date'];
      if (date is! Timestamp || !date.toDate().isAfter(DateTime.now())) {
        throw const SocialInteractionException(
          'Maçın tarihi geçmiş veya geçersiz.',
        );
      }
      final path = 'users/$target/notifications/match_invite_$id';
      if (await tx.read(path) != null) return;
      final title = match['title'] ?? 'Maç';
      tx.set(path, {
        'title': 'Maç Daveti ⚽',
        'message': 'Seni "$title" maçına davet etti.',
        'type': 'match_invite',
        'matchId': matchId,
        'matchTitle': title,
        'matchDate': date,
        'fromUid': uid,
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    });
  }
}
