import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halisaha_app/core/services/social_interactions.dart';

// Stages writes until successful completion and rejects reads after writes,
// matching the transaction contract used by the Firestore adapter.
class MemorySocialStore implements SocialStore {
  final docs = <String, Map<String, dynamic>>{
    'users/alice': {'name': 'Alice'},
    'users/bob': {'name': 'Bob'},
    'matches/game': {
      'createdBy': 'alice',
      'title': 'Test',
      'date': Timestamp.fromDate(DateTime.now().add(const Duration(days: 1))),
    },
  };
  int counter = 0;
  bool failCommit = false;
  @override
  String newId() => 'notice-${counter++}';
  @override
  Future<void> run(Future<void> Function(SocialTransaction) action) async {
    final tx = MemorySocialTransaction(docs);
    await action(tx);
    if (failCommit) throw StateError('simulated commit failure');
    for (final write in tx.writes) {
      write();
    }
  }
}

class MemorySocialTransaction implements SocialTransaction {
  MemorySocialTransaction(this.docs);
  final Map<String, Map<String, dynamic>> docs;
  final writes = <void Function()>[];
  @override
  Future<Map<String, dynamic>?> read(String path) async {
    if (writes.isNotEmpty) throw StateError('read after write');
    return docs[path];
  }

  @override
  void set(String path, Map<String, dynamic> data) =>
      writes.add(() => docs[path] = Map.of(data));
  @override
  void update(String path, Map<String, dynamic> data) =>
      writes.add(() => docs[path]!.addAll(data));
  @override
  void delete(String path) => writes.add(() => docs.remove(path));
}

void main() {
  late MemorySocialStore store;
  late SocialInteractions alice;
  setUp(() {
    store = MemorySocialStore();
    alice = SocialInteractions(store: store, currentUid: () => 'alice');
  });
  final rejected = isA<SocialInteractionException>();

  test(
    'both blocking directions stop requests, acceptance and invitations',
    () async {
      for (final pair in [('alice', 'bob'), ('bob', 'alice')]) {
        store.docs['users/${pair.$1}']!['blockedUsers'] = [pair.$2];
        store.docs['users/alice/followRequests/bob'] = {
          'from': 'bob',
          'status': 'pending',
        };
        await expectLater(alice.requestFollow('bob'), throwsA(rejected));
        await expectLater(alice.acceptFollow('bob'), throwsA(rejected));
        await expectLater(alice.invite('bob', 'game'), throwsA(rejected));
        expect(
          store.docs.keys.where((p) => p.contains('/notifications/')),
          isEmpty,
        );
        expect(store.docs.keys.where((p) => p.contains('/friends/')), isEmpty);
        store.docs['users/${pair.$1}']!.remove('blockedUsers');
      }
    },
  );

  test(
    'duplicate request creates one unread notification; failure commits neither',
    () async {
      store.failCommit = true;
      await expectLater(alice.requestFollow('bob'), throwsStateError);
      expect(store.docs.containsKey('users/bob/followRequests/alice'), false);
      expect(
        store.docs.keys.where((p) => p.contains('/notifications/')),
        isEmpty,
      );
      store.failCommit = false;
      await alice.requestFollow('bob');
      await alice.requestFollow('bob');
      final notices = store.docs.entries.where(
        (d) => d.key.contains('/notifications/'),
      );
      expect(notices.length, 1);
      expect(notices.single.value['isRead'], false);
      expect(notices.single.value['senderUid'], 'alice');
    },
  );

  test('cancelled or forged request cannot create a friendship', () async {
    await expectLater(alice.acceptFollow('bob'), throwsA(rejected));
    store.docs['users/alice/followRequests/bob'] = {
      'from': 'mallory',
      'status': 'pending',
    };
    await expectLater(alice.acceptFollow('bob'), throwsA(rejected));
    store.docs['users/alice/followRequests/bob'] = {
      'from': 'bob',
      'status': 'rejected',
    };
    await expectLater(alice.acceptFollow('bob'), throwsA(rejected));
    expect(store.docs.keys.where((p) => p.contains('/friends/')), isEmpty);
  });

  test(
    'accept uses real profiles, clears crossed requests and validates notification',
    () async {
      store.docs['users/alice/followRequests/bob'] = {
        'from': 'bob',
        'status': 'pending',
      };
      store.docs['users/bob/followRequests/alice'] = {
        'from': 'alice',
        'status': 'pending',
      };
      store.docs['users/alice/notifications/notice'] = {
        'type': 'follow_request',
        'senderUid': 'mallory',
      };
      await expectLater(
        alice.acceptFollow('bob', notificationId: 'notice'),
        throwsA(rejected),
      );
      store.docs['users/alice/notifications/notice']!['senderUid'] = 'bob';
      await alice.acceptFollow('bob', notificationId: 'notice');
      expect(store.docs['users/alice/friends/bob']!['fullName'], 'Bob');
      expect(store.docs['users/bob/friends/alice']!['fullName'], 'Alice');
      expect(
        store.docs.keys.where((p) => p.contains('/followRequests/')),
        isEmpty,
      );
      expect(
        store.docs['users/alice/notifications/notice']!['status'],
        'accepted',
      );
    },
  );

  test(
    'invite is deduplicated and verifies current match owner and date',
    () async {
      store.docs['matches/game']!['createdBy'] = 'bob';
      await expectLater(alice.invite('bob', 'game'), throwsA(rejected));
      store.docs['matches/game']!['createdBy'] = 'alice';
      final date = store.docs['matches/game']!['date'];
      store.docs['matches/game']!['date'] =
          Timestamp.fromMillisecondsSinceEpoch(0);
      await expectLater(alice.invite('bob', 'game'), throwsA(rejected));
      store.docs['matches/game']!['date'] = date;
      await alice.invite('bob', 'game');
      await alice.invite('bob', 'game');
      final notices = store.docs.entries.where(
        (d) => d.key.contains('/notifications/'),
      );
      expect(notices.length, 1);
      expect(notices.single.value['type'], 'match_invite');
      expect(notices.single.value['fromUid'], 'alice');
    },
  );

  test(
    'block clears both directions including asymmetric friendship remnants',
    () async {
      store.docs['users/bob/friends/alice'] = {'uid': 'alice'};
      store.docs['users/alice/followRequests/bob'] = {'from': 'bob'};
      store.docs['users/bob/followRequests/alice'] = {'from': 'alice'};
      await alice.block('bob');
      expect(
        store.docs.keys.where(
          (p) => p.contains('/friends/') || p.contains('/followRequests/'),
        ),
        isEmpty,
      );
      expect(store.docs['users/alice']!.containsKey('blockedUsers'), true);
    },
  );

  test(
    'missing auth/profile, malformed blocks and path input fail closed',
    () async {
      final anonymous = SocialInteractions(
        store: store,
        currentUid: () => null,
      );
      await expectLater(anonymous.requestFollow('bob'), throwsA(rejected));
      await expectLater(alice.requestFollow('alice'), throwsA(rejected));
      await expectLater(alice.requestFollow('bob/path'), throwsA(rejected));
      await expectLater(alice.requestFollow('missing'), throwsA(rejected));
      store.docs['users/bob']!['blockedUsers'] = 'invalid';
      await expectLater(alice.requestFollow('bob'), throwsA(rejected));
      expect(
        store.docs.keys.where((p) => p.contains('/notifications/')),
        isEmpty,
      );
    },
  );
}
