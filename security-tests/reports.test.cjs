const { before, after, test } = require('node:test');
const { readFileSync } = require('node:fs');
const { initializeTestEnvironment, assertFails } = require('@firebase/rules-unit-testing');
const { doc, setDoc, getDoc, getDocs, collection, updateDoc, deleteDoc, serverTimestamp } = require('firebase/firestore');

let env;
before(async () => {
  if (process.env.GCLOUD_PROJECT !== 'demo-depar-review' ||
      process.env.FIRESTORE_EMULATOR_HOST !== '127.0.0.1:8088') {
    throw new Error('Tests require the local demo emulator; production is forbidden.');
  }
  env = await initializeTestEnvironment({
    projectId: 'demo-depar-review',
    firestore: { host: '127.0.0.1', port: 8088, rules: readFileSync('firestore.rules', 'utf8') },
  });
  await env.withSecurityRulesDisabled(async context => {
    const db = context.firestore();
    await setDoc(doc(db, 'users/target'), { name: 'Test' });
    await setDoc(doc(db, 'users/alice'), { name: 'Test' });
    await setDoc(doc(db, 'matches/game'), { title: 'Test' });
  });
});
after(async () => { if (env) await env.cleanup(); });

function report(overrides = {}) {
  return { type: 'user', targetId: 'target', reporterId: 'alice', reason: 'spam', createdAt: serverTimestamp(), status: 'pending', ...overrides };
}
test('client cannot create reports directly or read/modify server records', async () => {
  const db = env.authenticatedContext('alice').firestore();
  const ref = doc(db, 'contentReports/alice_user_target');
  await assertFails(setDoc(ref, report()));
  await env.withSecurityRulesDisabled(async context => {
    await setDoc(doc(context.firestore(), ref.path), report());
  });
  await assertFails(getDoc(ref));
  await assertFails(getDocs(collection(db, 'contentReports')));
  await assertFails(setDoc(ref, report()));
  await assertFails(updateDoc(ref, { status: 'resolved' }));
  await assertFails(deleteDoc(ref));
  const other = env.authenticatedContext('bob', { admin: true }).firestore();
  await assertFails(getDoc(doc(other, ref.path)));
  await assertFails(updateDoc(doc(other, ref.path), { status: 'resolved' }));
});
test('direct match reports must use the server too', async () => {
  await assertFails(setDoc(doc(env.authenticatedContext('alice').firestore(), 'contentReports/alice_match_game'), report({ type: 'match', targetId: 'game' })));
});
test('forged identity, anonymous submissions and invented targets are rejected', async () => {
  await assertFails(setDoc(doc(env.unauthenticatedContext().firestore(), 'contentReports/alice_user_target'), report()));
  await assertFails(setDoc(doc(env.authenticatedContext('bob').firestore(), 'contentReports/alice_user_target'), report()));
  await assertFails(setDoc(doc(env.authenticatedContext('alice').firestore(), 'contentReports/alice_user_missing'), report({ targetId: 'missing' })));
  await assertFails(setDoc(doc(env.authenticatedContext('alice').firestore(), 'contentReports/alice_user_alice'), report({ targetId: 'alice' })));
});
test('status, timestamp, type, fields and ID are constrained', async () => {
  const db = env.authenticatedContext('carol').firestore();
  const ref = doc(db, 'contentReports/carol_user_target');
  for (const invalid of [
    { status: 'resolved' }, { createdAt: new Date(0) }, { type: 'admin' },
    { reason: 'invented' }, { admin: true }, { targetId: '' }, { targetId: 'users/target' },
  ]) {
    await assertFails(setDoc(ref, report({ reporterId: 'carol', ...invalid })));
  }
  await assertFails(setDoc(doc(db, 'contentReports/arbitrary'), report({ reporterId: 'carol' })));
  const missing = report({ reporterId: 'carol' });
  delete missing.reason;
  await assertFails(setDoc(ref, missing));
});
