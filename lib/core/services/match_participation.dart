import 'package:cloud_firestore/cloud_firestore.dart';
import 'match_metadata.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'social_interactions.dart';

class MatchActionException implements Exception {
  const MatchActionException(this.message);
  final String message;
}

/// Every operation reads the current match inside a retryable transaction.
/// UI snapshots are never used as the authoritative roster.
class MatchParticipation {
  MatchParticipation({SocialStore? store, String? Function()? currentUid})
    : _store = store ?? FirestoreSocialStore(FirebaseFirestore.instance),
      _uid = currentUid ?? (() => FirebaseAuth.instance.currentUser?.uid);
  final SocialStore _store;
  final String? Function() _uid;
  String get actor {
    final value = _uid();
    if (value == null || value.isEmpty) _fail('Lütfen yeniden giriş yapın.');
    return value;
  }

  static Never _fail(String message) => throw MatchActionException(message);
  static String owner(Map<String, dynamic> m) =>
      (m['createdBy'] ?? m['creatorId'] ?? '') as String;
  static Map<String, String> slots(Map<String, dynamic> m, String field) =>
      Map<String, String>.from(m[field] as Map? ?? {});
  static List<String> players(Map<String, dynamic> m) =>
      List<String>.from(m['currentPlayers'] ?? []);
  static bool validSlot(String slot, int capacity) {
    final value = slot.startsWith('opponent_') ? slot.substring(9) : slot;
    final index = int.tryParse(value);
    return index != null &&
        value == '$index' &&
        index >= 0 &&
        index < capacity ~/ 2;
  }

  Future<Map<String, dynamic>> _read(SocialTransaction tx, String id) async {
    if (id.isEmpty || id.contains('/')) _fail('Geçersiz maç.');
    final m = await tx.read('matches/$id');
    if (m == null) _fail('Maç artık mevcut değil.');
    return m;
  }

  void _active(Map<String, dynamic> m) {
    if (m['date'] is! Timestamp ||
        !(m['date'] as Timestamp).toDate().isAfter(DateTime.now()) ||
        m['status'] != 'open') {
      _fail('Bu maç artık katılıma açık değil.');
    }
  }

  Future<void> _pair(SocialTransaction tx, String a, String b) async {
    if (a == b) return;
    final first = await tx.read('users/$a');
    final second = await tx.read('users/$b');
    if (first == null ||
        second == null ||
        (first['blockedUsers'] as List? ?? []).contains(b) ||
        (second['blockedUsers'] as List? ?? []).contains(a)) {
      _fail('Bu kullanıcıyla maç işlemi yapılamıyor.');
    }
  }

  String _slotOf(Map<String, String> map, String uid) =>
      map.entries.where((e) => e.value == uid).map((e) => e.key).firstOrNull ??
      '';

  Map<String, String> _change(
    Map<String, dynamic> m,
    String uid,
    Map<String, String> next,
  ) => {
    'from': _slotOf(slots(m, 'positions'), uid),
    'to': _slotOf(next, uid),
    'pending': _slotOf(slots(m, 'pendingPositions'), uid),
  };

  Map<String, dynamic> _roster(
    Map<String, dynamic> m,
    List<String> members,
    Map<String, String> positions,
    Map<String, String> pending,
    String target,
  ) => {
    'currentPlayers': members,
    'positions': positions,
    'pendingPositions': pending,
    'invitedPlayers': pending.values.toSet().toList(),
    'slotChange': _change(m, target, positions),
    if (owner(m) == actor)
      'inviteSlot': _slotOf(slots(m, 'pendingPositions'), target),
  };
  Future<void> join(String id) async {
    final uid = actor;
    await _store.run((tx) async {
      final m = await _read(tx, id);
      _active(m);
      await _pair(tx, uid, owner(m));
      final members = players(m);
      if (members.contains(uid)) return;
      if (members.length >= (m['maxPlayers'] as int)) {
        _fail('Maçın kontenjanı dolu.');
      }
      final pending = slots(m, 'pendingPositions')
        ..removeWhere((_, v) => v == uid);
      members.add(uid);
      tx.update(
        'matches/$id',
        _roster(m, members, slots(m, 'positions'), pending, uid),
      );
    });
  }

  Future<void> editDetails(String id, Map<String, dynamic> changes) async {
    final uid = actor;
    const allowed = {
      'title',
      'venue',
      'venueId',
      'latitude',
      'longitude',
      'price',
      'maxPlayers',
      'date',
      'endDate',
      'teamA_name',
      'teamB_name',
    };
    if (changes.keys.any((k) => !allowed.contains(k))) {
      _fail('Geçersiz maç alanı.');
    }
    await _store.run((tx) async {
      final m = await _read(tx, id);
      if (owner(m) != uid) _fail('Maçı yalnızca kurucu düzenleyebilir.');
      final capacity = changes['maxPlayers'] ?? m['maxPlayers'];
      if (capacity is! int ||
          capacity < 10 ||
          capacity > 22 ||
          capacity.isOdd ||
          players(m).length > capacity ||
          [
            ...slots(m, 'positions').keys,
            ...slots(m, 'pendingPositions').keys,
          ].any((slot) => !validSlot(slot, capacity))) {
        _fail('Yeni kapasite mevcut kadro veya pozisyonlarla uyumlu değil.');
      }
      final patch = {...changes};
      // A format change also selects a valid formation for the new team size.
      if (capacity != m['maxPlayers'] &&
          !MatchMetadata.formations(capacity).contains(m['formation'])) {
        patch['formation'] = MatchMetadata.formations(capacity).first;
      }
      final updated = {...m, ...patch};
      final issue = MatchMetadata.error(updated);
      if (issue != null) _fail(issue);
      if (updated['date'] != m['date'] &&
          !(updated['date'] as Timestamp).toDate().isAfter(DateTime.now())) {
        _fail('Maç tarihi geçmişe taşınamaz.');
      }
      tx.update('matches/$id', patch);
    });
  }

  Future<void> leave(String id) => _remove(id, actor, false);
  Future<void> kick(String id, String target) => _remove(id, target, true);
  Future<void> _remove(String id, String target, bool captain) async {
    final uid = actor;
    await _store.run((tx) async {
      final m = await _read(tx, id);
      if (captain && owner(m) != uid) _fail('Oyuncu çıkarma yetkiniz yok.');
      if (target == owner(m)) {
        _fail('Kurucu maçtan ayrılamaz; maçı iptal edebilir.');
      }
      final members = players(m)..removeWhere((v) => v == target);
      final position = slots(m, 'positions')
        ..removeWhere((_, v) => v == target);
      final pending = slots(m, 'pendingPositions')
        ..removeWhere((_, v) => v == target);
      tx.update('matches/$id', _roster(m, members, position, pending, target));
    });
  }

  Future<void> move(String id, String slot) async {
    final uid = actor;
    await _store.run((tx) async {
      final m = await _read(tx, id);
      _active(m);
      await _pair(tx, uid, owner(m));
      if (!players(m).contains(uid)) _fail('Önce maçın kadrosuna katılın.');
      if (!validSlot(slot, m['maxPlayers'] as int)) _fail('Geçersiz pozisyon.');
      final positions = slots(m, 'positions');
      final pending = slots(m, 'pendingPositions');
      if ((positions.containsKey(slot) && positions[slot] != uid) ||
          pending.containsKey(slot)) {
        _fail('Bu pozisyon dolu veya davet için ayrılmış.');
      }
      positions.removeWhere((_, v) => v == uid);
      positions[slot] = uid;
      tx.update('matches/$id', {
        'positions': positions,
        'slotChange': _change(m, uid, positions),
      });
    });
  }

  Future<void> respond(
    String id,
    String noticeId,
    String slot, {
    required bool accept,
  }) async {
    final uid = actor;
    if (noticeId.isEmpty || noticeId.contains('/')) _fail('Geçersiz davet.');
    await _store.run((tx) async {
      final m = await _read(tx, id);
      final path = 'notifications/$noticeId';
      final notice = await tx.read(path);
      final pending = slots(m, 'pendingPositions');
      if (notice == null ||
          notice['receiverId'] != uid ||
          notice['senderId'] != owner(m) ||
          notice['type'] != 'match_invite' ||
          notice['status'] != 'pending' ||
          notice['matchId'] != id ||
          notice['positionId'] != slot ||
          pending[slot] != uid) {
        _fail('Bu davet artık geçerli değil.');
      }
      final members = players(m);
      final positions = slots(m, 'positions');
      if (accept) {
        _active(m);
        await _pair(tx, uid, owner(m));
        if (!validSlot(slot, m['maxPlayers'] as int) ||
            positions.containsKey(slot)) {
          _fail('Pozisyon artık boş değil.');
        }
        if (!members.contains(uid) &&
            members.length >= (m['maxPlayers'] as int)) {
          _fail('Maçın kontenjanı dolu.');
        }
        if (!members.contains(uid)) members.add(uid);
        positions.removeWhere((_, v) => v == uid);
        positions[slot] = uid;
      }
      pending.removeWhere((_, v) => v == uid);
      tx.update('matches/$id', _roster(m, members, positions, pending, uid));
      if (accept) {
        tx.update(path, {'status': 'accepted', 'isRead': true});
      } else {
        tx.delete(path);
        // Rejection itself must remain possible after a block; do not send a
        // new social message to the blocked party.
      }
    });
  }

  /// Saves only formation and explicit invite differences, never a stale roster.
  /// Each invite is its own transaction to stay below rule document-read limits.
  Future<void> saveFormation(
    String id,
    String formation,
    Map<String, String> base,
    Map<String, String> desired,
  ) async {
    final uid = actor;
    for (final slot in {...base.keys, ...desired.keys}) {
      if (base[slot] == desired[slot]) continue;
      final notificationId = _store.newId();
      await _store.run((tx) async {
        final m = await _read(tx, id);
        if (owner(m) != uid) _fail('Dizilişi yalnızca kurucu kaydedebilir.');
        _active(m);
        if (!MatchMetadata.formations(
          m['maxPlayers'] as int,
        ).contains(formation)) {
          _fail('Geçersiz diziliş.');
        }
        final pending = slots(m, 'pendingPositions');
        if (pending[slot] == desired[slot]) return; // retry after partial save
        if (pending[slot] != base[slot]) {
          _fail('Davetler değişti. Güncel kadroyu kontrol edin.');
        }
        final target = desired[slot];
        if (target != null) {
          await _pair(tx, uid, target);
          if (!validSlot(slot, m['maxPlayers'] as int) ||
              slots(m, 'positions').containsKey(slot) ||
              players(m).contains(target) ||
              pending.entries.any((e) => e.key != slot && e.value == target)) {
            _fail('Oyuncu veya pozisyon davet için uygun değil.');
          }
          pending[slot] = target;
        } else {
          pending.remove(slot);
        }
        tx.update('matches/$id', {
          'inviteSlot': slot,
          'pendingPositions': pending,
          'invitedPlayers': pending.values.toList(),
        });
        if (target != null) {
          tx.set('notifications/$notificationId', {
            'type': 'match_invite',
            'senderId': uid,
            'receiverId': target,
            'matchId': id,
            'positionId': slot,
            'status': 'pending',
            'isRead': false,
            'createdAt': FieldValue.serverTimestamp(),
          });
        }
      });
    }
    await _store.run((tx) async {
      final m = await _read(tx, id);
      if (owner(m) != uid) _fail('Dizilişi yalnızca kurucu kaydedebilir.');
      _active(m);
      if (!MatchMetadata.formations(
        m['maxPlayers'] as int,
      ).contains(formation)) {
        _fail('Geçersiz diziliş.');
      }
      tx.update('matches/$id', {'formation': formation});
    });
  }
}
