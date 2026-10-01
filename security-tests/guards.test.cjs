const { before, after, test } = require('node:test');
const { readFileSync } = require('node:fs');
const { initializeTestEnvironment, assertFails, assertSucceeds } = require('@firebase/rules-unit-testing');
const { doc, setDoc, getDoc, deleteDoc } = require('firebase/firestore');
let env;
before(async () => {
  if (process.env.GCLOUD_PROJECT !== 'demo-depar-review' || process.env.FIRESTORE_EMULATOR_HOST !== '127.0.0.1:8088') throw new Error('Local demo emulator required');
  // Separate demo database namespace prevents test files replacing each other's rules.
  const fragment = readFileSync('../functions/rules/firestore.fragment.rules', 'utf8');
  env = await initializeTestEnvironment({ projectId: 'demo-depar-guards', firestore: {
    host: '127.0.0.1', port: 8088,
    rules: `rules_version = '2'; service cloud.firestore { match /databases/{database}/documents {
      ${fragment}
      match /testWrites/{uid} { allow write: if request.auth.uid == uid && safetyWritesAllowed(); }
    } }`,
  } });
});
after(async () => { if (env) await env.cleanup(); });
test('account job freezes only its user; legacy global lock no longer affects others', async () => {
  const alice = env.authenticatedContext('alice').firestore();
  const bob = env.authenticatedContext('bob').firestore();
  await assertSucceeds(setDoc(doc(alice, 'testWrites/alice'), { value: 1 }));
  await env.withSecurityRulesDisabled(async context => {
    const db = context.firestore();
    await setDoc(doc(db, '_safetyLocks/accountDeletion'), { uid: 'alice' });
    await setDoc(doc(db, 'accountDeletionJobs/alice'), { status: 'processing' });
  });
  await assertFails(setDoc(doc(alice, 'testWrites/alice'), { value: 2 }));
  await assertSucceeds(setDoc(doc(bob, 'testWrites/bob'), { value: 2 }));
  await assertFails(deleteDoc(doc(bob, '_safetyLocks/accountDeletion')));
  await assertFails(getDoc(doc(alice, 'accountDeletionJobs/alice')));
  await env.withSecurityRulesDisabled(async context => {
    await deleteDoc(doc(context.firestore(), '_safetyLocks/accountDeletion'));
  });
  await assertFails(setDoc(doc(alice, 'testWrites/alice'), { value: 3 }));
  await assertSucceeds(setDoc(doc(bob, 'testWrites/bob'), { value: 3 }));
});
