// These tests intentionally reproduce vulnerabilities in the supplied baseline.
// Passing means the exposure exists, NOT that production rules are safe.
const { before, after, beforeEach, test } = require('node:test');
const assert = require('node:assert/strict');
const { readFileSync } = require('node:fs');
const { initializeTestEnvironment, assertSucceeds, assertFails } = require('@firebase/rules-unit-testing');
const { doc, setDoc, getDoc, updateDoc, deleteDoc } = require('firebase/firestore');
let env;
before(async () => {
  if (process.env.GCLOUD_PROJECT !== 'demo-depar-review' ||
      process.env.FIRESTORE_EMULATOR_HOST !== '127.0.0.1:8088') throw new Error('Local demo emulator required');
  env = await initializeTestEnvironment({ projectId: 'demo-depar-baseline', firestore: {
    host: '127.0.0.1', port: 8088,
    rules: readFileSync('fixtures/user-provided.firestore.rules', 'utf8'),
  } });
});
after(async () => { if (env) await env.cleanup(); });
beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async context => {
    const db = context.firestore();
    await setDoc(doc(db, 'users/alice'), { email: 'synthetic@example.invalid', blockedUsers: ['mallory'] });
    await setDoc(doc(db, 'matches/game'), { createdBy: 'alice', creatorId: 'alice', title: 'Original' });
    await setDoc(doc(db, 'notifications/private'), { receiverId: 'alice', senderId: 'bob' });
  });
});
test('UNSAFE baseline: anonymous visitors can read profile email', async () => {
  const db = env.unauthenticatedContext().firestore();
  const snap = await assertSucceeds(getDoc(doc(db, 'users/alice')));
  assert.equal(snap.data().email, 'synthetic@example.invalid');
});
test('UNSAFE baseline: unrelated blocked account can forge social records and notifications', async () => {
  const db = env.authenticatedContext('mallory').firestore();
  await assertSucceeds(setDoc(doc(db, 'users/alice/friends/bob'), { uid: 'bob' }));
  await assertSucceeds(setDoc(doc(db, 'users/alice/followRequests/bob'), { from: 'bob', status: 'pending' }));
  await assertSucceeds(setDoc(doc(db, 'users/alice/notifications/forged'), { senderUid: 'bob' }));
  await assertSucceeds(getDoc(doc(db, 'notifications/private')));
  await assertSucceeds(deleteDoc(doc(db, 'notifications/private')));
});
test('UNSAFE baseline: unrelated account can take match ownership then delete it', async () => {
  const db = env.authenticatedContext('mallory').firestore();
  await assertFails(deleteDoc(doc(db, 'matches/game')));
  await assertSucceeds(updateDoc(doc(db, 'matches/game'), { creatorId: 'mallory', createdBy: 'mallory' }));
  await assertSucceeds(deleteDoc(doc(db, 'matches/game')));
});
test('UNSAFE baseline: account-deletion barrier does not protect existing write grants', async () => {
  await env.withSecurityRulesDisabled(async context => {
    const db = context.firestore();
    await setDoc(doc(db, '_safetyLocks/accountDeletion'), { uid: 'alice' });
    await setDoc(doc(db, 'accountDeletionJobs/alice'), { status: 'processing' });
  });
  const db = env.authenticatedContext('alice').firestore();
  await assertSucceeds(updateDoc(doc(db, 'users/alice'), { name: 'still writable' }));
  await assertSucceeds(deleteDoc(doc(db, 'venues/arbitrary')));
});
