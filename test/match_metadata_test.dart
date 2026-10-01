import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halisaha_app/core/services/match_metadata.dart';
import 'package:halisaha_app/core/services/match_participation.dart';
import 'social_interactions_test.dart' show MemorySocialStore;

Map<String, dynamic> sample() => {
  'title': 'Akşam maçı',
  'date': Timestamp.fromDate(DateTime(2035, 1, 1, 23)),
  'endDate': Timestamp.fromDate(DateTime(2035, 1, 2)),
  'price': 250.5,
  'maxPlayers': 14,
  'status': 'open',
  'venue': 'Saha',
  'latitude': 40.5,
  'longitude': 30.5,
};

void main() {
  test(
    'manual coordinates, zero cost and midnight-crossing duration are valid',
    () {
      expect(MatchMetadata.error(sample()), isNull);
      expect(
        MatchMetadata.error({
          ...sample(),
          'latitude': null,
          'longitude': null,
          'price': 0,
        }),
        isNull,
      );
      expect(
        MatchMetadata.error({
          'title': 'Minimal',
          'date': Timestamp.now(),
          'maxPlayers': 10,
          'status': 'open',
        }),
        isNull,
      );
    },
  );

  test(
    'invalid prices, coordinates, text and times produce a user-facing error',
    () {
      final start = sample()['date'] as Timestamp;
      for (final patch in <Map<String, dynamic>>[
        {'title': ' '},
        {'title': 'x' * 121},
        {'price': double.nan},
        {'price': double.infinity},
        {'price': -1},
        {'price': '250'},
        {'latitude': 91},
        {'longitude': null},
        {'teamA_name': 'x' * 61},
        {'venue': 'x' * 201},
        {'venueId': 'other/path'},
        {'endDate': start},
        {'endDate': null},
        {'maxPlayers': 13},
        {'formation': '4-4-2'},
        {
          'endDate': Timestamp.fromDate(
            start.toDate().add(const Duration(hours: 25)),
          ),
        },
      ]) {
        expect(
          MatchMetadata.error({...sample(), ...patch}),
          isNotNull,
          reason: patch.keys.join(','),
        );
      }
    },
  );

  test(
    'owner edits validate merged metadata; format changes also fix formation without changing roster',
    () async {
      final store = MemorySocialStore();
      store.docs['matches/game'] = {
        ...sample(),
        'createdBy': 'alice',
        'creatorId': 'alice',
        'currentPlayers': ['alice'],
        'positions': {'0': 'alice'},
        'formation': '2-3-1',
      };
      final service = MatchParticipation(
        store: store,
        currentUid: () => 'alice',
      );
      await expectLater(
        service.editDetails('game', {'price': -1}),
        throwsA(isA<MatchActionException>()),
      );
      expect(store.docs['matches/game']!['price'], 250.5);
      await service.editDetails('game', {'maxPlayers': 22});
      expect(store.docs['matches/game']!['formation'], '4-4-2');
      expect(store.docs['matches/game']!['currentPlayers'], ['alice']);
      expect(store.docs['matches/game']!['positions'], {'0': 'alice'});
      final past = Timestamp.fromDate(DateTime(2000));
      await expectLater(
        service.editDetails('game', {
          'date': past,
          'endDate': Timestamp.fromDate(DateTime(2000, 1, 1, 1)),
        }),
        throwsA(isA<MatchActionException>()),
      );
    },
  );

  test('invalid formation fails before committing invitations', () async {
    final store = MemorySocialStore();
    store.docs['matches/game'] = {
      ...sample(),
      'createdBy': 'alice',
      'currentPlayers': ['alice'],
    };
    final service = MatchParticipation(store: store, currentUid: () => 'alice');
    await expectLater(
      service.saveFormation('game', '4-4-2', {}, {'1': 'bob'}),
      throwsA(isA<MatchActionException>()),
    );
    expect(store.docs['matches/game']!['pendingPositions'], isNull);
    expect(
      store.docs.keys.where((p) => p.startsWith('notifications/')),
      isEmpty,
    );
  });
}
