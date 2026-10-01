const { before, after, beforeEach, test } = require('node:test');
const { readFileSync } = require('node:fs');
const { initializeTestEnvironment, assertSucceeds, assertFails } = require('@firebase/rules-unit-testing');
const { doc, setDoc, getDoc, updateDoc, deleteDoc, writeBatch, serverTimestamp, Timestamp } = require('firebase/firestore');
let env;
before(async () => {
  if (process.env.GCLOUD_PROJECT !== 'demo-depar-review' ||
      process.env.FIRESTORE_EMULATOR_HOST !== '127.0.0.1:8088') throw new Error('Local demo emulator required');
  const fragments = ['firestore', 'profile', 'social', 'match-ownership']
    .map(name => readFileSync(`../functions/rules/${name}.fragment.rules`, 'utf8')).join('\n');
  env = await initializeTestEnvironment({ projectId: 'demo-depar-social', firestore: {
    host: '127.0.0.1', port: 8088,
    // Only the reviewed paths are assembled here. This fixture is NOT deployable.
    rules: `rules_version = '2'; service cloud.firestore { match /databases/{database}/documents {
      ${fragments}
      match /matches/{id} {
        allow read: if request.auth != null;
        allow create: if safetyWritesAllowed() && validNewMatchOwner();
        allow update: if safetyWritesAllowed() && matchOwnerUnchanged();
        allow delete: if safetyWritesAllowed() && canDeleteMatch();
      }
    } }`,
  } });
});
after(async () => { if (env) await env.cleanup(); });
beforeEach(async () => {
  await env.clearFirestore();
  await seed({
    'users/alice': { name: 'Alice', blockedUsers: [] },
    'users/bob': { name: 'Bob', blockedUsers: [] },
    'users/mallory': { name: 'Mallory', blockedUsers: [] },
    'matches/game': { createdBy: 'alice', creatorId: 'alice', title: 'Test', date: Timestamp.fromMillis(Date.now() + 86400000) },
  });
});
async function seed(data) {
  await env.withSecurityRulesDisabled(async context => {
    const db = context.firestore();
    for (const [path, value] of Object.entries(data)) {
      await setDoc(doc(db, path), /^users\/[^/]+$/.test(path) ? {profileVersion:2, ...value} : value);
    }
  });
}
function client(uid) { return env.authenticatedContext(uid).firestore(); }
function requestAndNotice(db, sender = 'alice', receiver = 'bob', noticeId = 'notice') {
  const batch = writeBatch(db);
  batch.set(doc(db, `users/${receiver}/followRequests/${sender}`), {
    from: sender, status: 'pending', createdAt: serverTimestamp(),
  });
  batch.set(doc(db, `users/${receiver}/notifications/${noticeId}`), {
    type: 'follow_request', senderUid: sender, senderName: 'Alice',
    title: 'Yeni Takip İsteği 👥', message: 'Alice seninle arkadaş olmak istiyor.',
    status: 'pending', isRead: false, createdAt: serverTimestamp(),
  });
  return batch;
}
function friend(uid, name) {
  return { uid, fullName: name, avatarUrl: '', avatarData: '0', position: '', since: serverTimestamp() };
}
function accept(db, { both = true, remove = true } = {}) {
  const batch = writeBatch(db);
  batch.set(doc(db, 'users/bob/friends/alice'), friend('alice', 'Alice'));
  if (both) batch.set(doc(db, 'users/alice/friends/bob'), friend('bob', 'Bob'));
  if (remove) batch.delete(doc(db, 'users/bob/followRequests/alice'));
  batch.delete(doc(db, 'users/alice/followRequests/bob'));
  batch.update(doc(db, 'users/bob/notifications/notice'), { status: 'accepted', isRead: true });
  return batch;
}
test('real request+notification and receiver acceptance succeed atomically', async () => {
  await assertSucceeds(requestAndNotice(client('alice')).commit());
  await assertSucceeds(accept(client('bob')).commit());
  await assertSucceeds(getDoc(doc(client('alice'), 'users/alice/friends/bob')));
});
test('third party cannot forge requests, friendship, notification or delete relationships', async () => {
  const db = client('mallory');
  await assertFails(requestAndNotice(db).commit());
  await assertFails(setDoc(doc(db, 'users/alice/friends/bob'), friend('bob', 'Bob')));
  await assertFails(deleteDoc(doc(db, 'users/alice/friends/bob')));
  await assertFails(setDoc(doc(db, 'users/alice/followers/bob'), { uid: 'bob' }));
});
test('sender cannot self-accept, and receiver cannot accept cancelled or partial requests', async () => {
  await assertSucceeds(requestAndNotice(client('alice')).commit());
  await assertFails(accept(client('alice')).commit());
  await assertFails(accept(client('bob'), { both: false }).commit());
  await assertFails(accept(client('bob'), { remove: false }).commit());
  await assertSucceeds(deleteDoc(doc(client('alice'), 'users/bob/followRequests/alice')));
  await assertFails(accept(client('bob')).commit());
});
test('block in either direction rejects new requests and acceptance of earlier requests', async () => {
  await assertSucceeds(requestAndNotice(client('alice')).commit());
  await assertSucceeds(updateDoc(doc(client('bob'), 'users/bob'), { blockedUsers: ['alice'] }));
  await assertFails(accept(client('bob')).commit());
  await assertFails(requestAndNotice(client('alice'), 'alice', 'bob', 'again').commit());
  await assertSucceeds(updateDoc(doc(client('bob'), 'users/bob'), { blockedUsers: [] }));
  await assertSucceeds(updateDoc(doc(client('alice'), 'users/alice'), { blockedUsers: ['bob'] }));
  await assertFails(accept(client('bob')).commit());
});
test('block cleanup may remove both friendship directions and both pending requests', async () => {
  await assertSucceeds(requestAndNotice(client('alice')).commit());
  await assertSucceeds(accept(client('bob')).commit());
  const db = client('alice');
  const batch = writeBatch(db);
  batch.update(doc(db, 'users/alice'), { blockedUsers: ['bob'] });
  for (const group of ['friends', 'followRequests']) {
    batch.delete(doc(db, `users/alice/${group}/bob`));
    batch.delete(doc(db, `users/bob/${group}/alice`));
  }
  await assertSucceeds(batch.commit());
});
test('notifications are private, sender cannot edit, owner cannot forge payload', async () => {
  await assertSucceeds(requestAndNotice(client('alice')).commit());
  const path = 'users/bob/notifications/notice';
  await assertFails(getDoc(doc(client('mallory'), path)));
  await assertFails(updateDoc(doc(client('alice'), path), { isRead: true }));
  await assertFails(updateDoc(doc(client('bob'), path), { senderUid: 'mallory' }));
  await assertSucceeds(updateDoc(doc(client('bob'), path), { isRead: true }));
  await assertSucceeds(deleteDoc(doc(client('bob'), path)));
});
test('match ownership cannot be added, removed, changed or forged; owner can edit/delete', async () => {
  const evil = client('mallory'), owner = client('alice');
  await assertFails(updateDoc(doc(evil, 'matches/game'), { creatorId: 'mallory', createdBy: 'mallory' }));
  await assertFails(setDoc(doc(owner, 'matches/game'), { creatorId: 'alice' }));
  await assertFails(setDoc(doc(evil, 'matches/new'), { creatorId: 'alice', createdBy: 'alice' }));
  await assertSucceeds(updateDoc(doc(owner, 'matches/game'), { title: 'Changed' }));
  await assertFails(deleteDoc(doc(evil, 'matches/game')));
  await assertSucceeds(deleteDoc(doc(owner, 'matches/game')));
});
test('deletion job rejects new interactions while unrelated writes and cleanup continue', async () => {
  await seed({ 'accountDeletionJobs/bob': { status: 'processing' } });
  await assertFails(requestAndNotice(client('alice')).commit());
  await seed({ '_safetyLocks/accountDeletion': { uid: 'bob' } });
  await assertSucceeds(updateDoc(doc(client('alice'), 'matches/game'), { title: 'Allowed' }));
  await assertSucceeds(deleteDoc(doc(client('alice'), 'users/alice/friends/bob')));
});
test('formation invite must come from owner and match the saved slot; only receiver accepts', async () => {
  const owner = client('alice');
  const send = writeBatch(owner);
  send.update(doc(owner, 'matches/game'), { pendingPositions: { '0': 'bob' }, invitedPlayers: ['bob'] });
  send.set(doc(owner, 'notifications/invite'), {
    type: 'match_invite', senderId: 'alice', receiverId: 'bob', matchId: 'game',
    positionId: '0', status: 'pending', isRead: false, createdAt: serverTimestamp(),
  });
  await assertSucceeds(send.commit());
  await assertFails(getDoc(doc(client('mallory'), 'notifications/invite')));
  await assertFails(deleteDoc(doc(client('mallory'), 'notifications/invite')));
  await assertFails(updateDoc(doc(owner, 'notifications/invite'), { status: 'accepted' }));
  const receiver = client('bob');
  await assertFails(updateDoc(doc(receiver, 'notifications/invite'), { status: 'accepted' }));
  const acceptInvite = writeBatch(receiver);
  acceptInvite.update(doc(receiver, 'matches/game'), { positions: { '0': 'bob' }, currentPlayers: ['alice', 'bob'], pendingPositions: {} });
  acceptInvite.update(doc(receiver, 'notifications/invite'), { status: 'accepted' });
  await assertSucceeds(acceptInvite.commit());
});
test('rejection notification accompanies actual removal from invitedPlayers', async () => {
  await seed({ 'matches/game': { createdBy: 'alice', creatorId: 'alice', invitedPlayers: ['bob'] } });
  const db = client('bob');
  const data = { receiverId: 'alice', senderId: 'bob', type: 'invite_rejected', matchId: 'game', status: 'unread', createdAt: serverTimestamp() };
  await assertFails(setDoc(doc(db, 'notifications/rejected'), data));
  const batch = writeBatch(db);
  batch.update(doc(db, 'matches/game'), { invitedPlayers: [] });
  batch.set(doc(db, 'notifications/rejected'), data);
  await assertSucceeds(batch.commit());
});
test('profile match invitation must use current owner identity and match content', async () => {
  const owner = client('alice');
  const match = (await getDoc(doc(owner, 'matches/game'))).data();
  const data = {
    type: 'match_invite', fromUid: 'alice', title: 'Maç Daveti ⚽', message: 'Seni "Test" maçına davet etti.',
    matchId: 'game', matchTitle: 'Test', matchDate: match.date, isRead: false, createdAt: serverTimestamp(),
  };
  await assertFails(setDoc(doc(client('mallory'), 'users/bob/notifications/invite'), data));
  await assertFails(setDoc(doc(owner, 'users/bob/notifications/invite'), { ...data, message: 'forged content' }));
  await assertSucceeds(setDoc(doc(owner, 'users/bob/notifications/invite'), data));
});
test('a batch cannot create a friendship while also blocking that person', async () => {
  await assertSucceeds(requestAndNotice(client('alice')).commit());
  const db = client('bob');
  const batch = accept(db);
  batch.update(doc(db, 'users/bob'), { blockedUsers: ['alice'] });
  await assertFails(batch.commit());
});
