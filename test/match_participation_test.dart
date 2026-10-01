import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halisaha_app/core/services/match_participation.dart';
import 'social_interactions_test.dart' show MemorySocialStore;

void main() {
  late MemorySocialStore store;
  late MatchParticipation alice, bob;
  setUp(() {
    store = MemorySocialStore();
    store.docs['matches/game'] = {
      'createdBy': 'alice',
      'creatorId': 'alice',
      'title': 'Test',
      'status': 'open',
      'date': Timestamp.fromDate(DateTime.now().add(const Duration(days: 1))),
      'maxPlayers': 10,
      'currentPlayers': ['alice'],
      'positions': {'0': 'alice'},
      'pendingPositions': <String, String>{},
      'invitedPlayers': <String>[],
    };
    alice = MatchParticipation(store: store, currentUid: () => 'alice');
    bob = MatchParticipation(store: store, currentUid: () => 'bob');
  });
  final rejected = isA<MatchActionException>();
  test(
    'join uses current capacity and no membership is saved on commit failure',
    () async {
      store.failCommit = true;
      await expectLater(bob.join('game'), throwsStateError);
      expect(store.docs['matches/game']!['currentPlayers'], ['alice']);
      store.failCommit = false;
      await bob.join('game');
      await bob.join('game');
      expect(store.docs['matches/game']!['currentPlayers'], ['alice', 'bob']);
      store.docs['matches/game']!['currentPlayers'] = [
        'alice',
        ...List.generate(9, (i) => 'p$i'),
      ];
      await expectLater(bob.join('game'), throwsA(rejected));
    },
  );
  test(
    'move requires membership, preserves others and emits bounded slot changes',
    () async {
      await expectLater(bob.move('game', '1'), throwsA(rejected));
      await bob.join('game');
      await expectLater(bob.move('game', '0'), throwsA(rejected));
      await bob.move('game', '1');
      await bob.move('game', 'opponent_4');
      expect(store.docs['matches/game']!['positions'], {
        '0': 'alice',
        'opponent_4': 'bob',
      });
      expect(store.docs['matches/game']!['slotChange'], {
        'from': '1',
        'to': 'opponent_4',
        'pending': '',
      });
      await expectLater(bob.move('game', '5'), throwsA(rejected));
    },
  );
  test(
    'leave removes all own roster entries; owner and non-owner kick are rejected',
    () async {
      await bob.join('game');
      await bob.move('game', '1');
      await expectLater(bob.kick('game', 'alice'), throwsA(rejected));
      await expectLater(alice.leave('game'), throwsA(rejected));
      await bob.leave('game');
      expect(store.docs['matches/game']!['positions'], {'0': 'alice'});
      expect(store.docs['matches/game']!['currentPlayers'], ['alice']);
    },
  );
  test(
    'real invitation is required and acceptance cleans pending and invited lists',
    () async {
      await alice.saveFormation('game', '1-2-1', {}, {'1': 'bob'});
      final id = store.docs.keys
          .singleWhere((k) => k.startsWith('notifications/'))
          .split('/')
          .last;
      await expectLater(
        alice.respond('game', id, '1', accept: true),
        throwsA(rejected),
      );
      await expectLater(
        bob.respond('game', id, '2', accept: true),
        throwsA(rejected),
      );
      await bob.respond('game', id, '1', accept: true);
      expect(store.docs['matches/game']!['positions'], {
        '0': 'alice',
        '1': 'bob',
      });
      expect(store.docs['matches/game']!['pendingPositions'], isEmpty);
      expect(store.docs['matches/game']!['invitedPlayers'], isEmpty);
      expect(store.docs['notifications/$id']!['status'], 'accepted');
      await expectLater(
        bob.respond('game', id, '1', accept: true),
        throwsA(rejected),
      );
    },
  );
  test(
    'invite save is retryable and never writes a stale position snapshot',
    () async {
      await alice.saveFormation('game', '1-2-1', {}, {'1': 'bob'});
      store.docs['matches/game']!['positions'] = {'opponent_0': 'alice'};
      await alice.saveFormation('game', '1-2-1', {}, {'1': 'bob'});
      expect(
        store.docs.keys.where((k) => k.startsWith('notifications/')).length,
        1,
      );
      expect(store.docs['matches/game']!['positions'], {'opponent_0': 'alice'});
      store.docs['matches/game']!['pendingPositions'] = {'1': 'charlie'};
      await expectLater(
        alice.saveFormation('game', '1-2-1', {'1': 'bob'}, {}),
        throwsA(rejected),
      );
      expect(store.docs['matches/game']!['pendingPositions'], {'1': 'charlie'});
    },
  );
  test(
    'blocking prevents acceptance but still permits rejection cleanup',
    () async {
      await alice.saveFormation('game', '1-2-1', {}, {'1': 'bob'});
      final id = store.docs.keys
          .singleWhere((k) => k.startsWith('notifications/'))
          .split('/')
          .last;
      store.docs['users/alice']!['blockedUsers'] = ['bob'];
      await expectLater(
        bob.respond('game', id, '1', accept: true),
        throwsA(rejected),
      );
      await bob.respond('game', id, '1', accept: false);
      expect(store.docs.containsKey('notifications/$id'), false);
      expect(store.docs['matches/game']!['pendingPositions'], isEmpty);
    },
  );
  test(
    'only owner can edit metadata; resizing cannot strand occupied positions',
    () async {
      await expectLater(
        bob.editDetails('game', {'title': 'Forged'}),
        throwsA(rejected),
      );
      await expectLater(
        alice.editDetails('game', {'createdBy': 'bob'}),
        throwsA(rejected),
      );
      store.docs['matches/game']!['maxPlayers'] = 22;
      store.docs['matches/game']!['positions'] = {'opponent_10': 'alice'};
      await expectLater(
        alice.editDetails('game', {'maxPlayers': 10}),
        throwsA(rejected),
      );
      await alice.editDetails('game', {'title': 'Updated'});
      expect(store.docs['matches/game']!['title'], 'Updated');
    },
  );
}
