const { test } = require('node:test');
const assert = require('node:assert/strict');
const { identity, exactFields, matchCleanup } = require('../src/policy.cjs');

test('only verified identity and recent authentication are accepted', () => {
  const now = 1800000000000;
  assert.throws(() => identity({ data: { uid: 'victim' } }), { code: 'unauthenticated' });
  for (const time of [undefined, '1800000000', now / 1000 - 301, now / 1000 + 61]) {
    assert.throws(() => identity({ auth: { uid: 'alice', token: { auth_time: time } } }, { recent: true, now }), { code: 'failed-precondition' });
  }
  assert.equal(identity({ auth: { uid: 'alice', token: { auth_time: now / 1000 - 10 } } }, { recent: true, now }), 'alice');
  assert.throws(() => exactFields({ uid: 'victim' }, []), { code: 'invalid-argument' });
});

test('match cleanup preserves unrelated players and recognizes pending profile copies', () => {
  assert.deepEqual(matchCleanup({
    currentPlayers: ['alice', 'bob'], invitedPlayers: ['alice', 'carol'],
    positions: { 1: 'alice', 2: 'bob' },
    pendingPositions: { 3: { uid: 'alice', name: 'private' }, 4: { uid: 'carol' } },
  }, 'alice'), {
    currentPlayers: ['bob'], invitedPlayers: ['carol'], positions: { 2: 'bob' },
    pendingPositions: { 4: { uid: 'carol' } },
  });
  assert.deepEqual(matchCleanup({ title: 'unchanged' }, 'alice'), {});
});
