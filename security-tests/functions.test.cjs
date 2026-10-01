const { test, before, after } = require('node:test');
const assert = require('node:assert/strict');
const { createRequire } = require('node:module');
const serverRequire = createRequire(require.resolve('../functions/package.json'));
const { initializeApp, deleteApp } = serverRequire('firebase-admin/app');
const { getFirestore } = serverRequire('firebase-admin/firestore');
const { getAuth } = serverRequire('firebase-admin/auth');
const { getStorage } = serverRequire('firebase-admin/storage');
let app, db, auth, bucket;
before(() => {
  if (process.env.GCLOUD_PROJECT !== 'demo-depar-review' ||
      process.env.FIRESTORE_EMULATOR_HOST !== '127.0.0.1:8088' ||
      process.env.FIREBASE_AUTH_EMULATOR_HOST !== '127.0.0.1:9098' ||
      process.env.FIREBASE_STORAGE_EMULATOR_HOST !== '127.0.0.1:9198') throw new Error('All local demo emulators required');
  app = initializeApp({ projectId: 'demo-depar-review', storageBucket: 'demo-depar-review.appspot.com' }, 'function-e2e');
  db = getFirestore(app); auth = getAuth(app); bucket = getStorage(app).bucket();
});
after(async () => { if (app) await deleteApp(app); });
async function call(name, token, data = {}) {
  const response = await fetch(`http://127.0.0.1:5008/demo-depar-review/europe-west1/${name}`, {
    method: 'POST', headers: { 'Content-Type': 'application/json', ...(token ? { Authorization: `Bearer ${token}` } : {}) },
    body: JSON.stringify({ data }),
    signal: AbortSignal.timeout(20000),
  });
  return response.json();
}
test('actual callable authentication and Firestore trigger finish a demo deletion', { timeout: 90000 }, async () => {
  const signup = await fetch('http://127.0.0.1:9098/identitytoolkit.googleapis.com/v1/accounts:signUp?key=emulator-only', {
    method: 'POST', headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ email: 'e2e@example.invalid', password: 'emulator-test-password', returnSecureToken: true }),
  });
  const session = await signup.json();
  assert.ok(session.localId && session.idToken);
  const uid = session.localId;
  await db.doc(`users/${uid}`).set({ name: 'emulator only' });
  await bucket.file(`profile_images/${uid}.jpg`).save(Buffer.from('emulator fixture'));
  assert.equal((await call('safetyStatus', null)).error.status, 'UNAUTHENTICATED');
  assert.equal((await call('safetyStatus', session.idToken)).result.deletionEnabled, true);
  assert.equal((await call('prepareAccountDeletion', session.idToken)).result.ready, true);
  assert.equal((await call('requestAccountDeletion', session.idToken, { uid: 'victim' })).error.status, 'INVALID_ARGUMENT');
  assert.equal((await call('requestAccountDeletion', session.idToken)).result.accepted, true);
  const deadline = Date.now() + 60000;
  while (Date.now() < deadline) {
    if ((await db.doc(`accountDeletionJobs/${uid}`).get()).data()?.status === 'completed') break;
    await new Promise(resolve => setTimeout(resolve, 300));
  }
  assert.equal((await db.doc(`accountDeletionJobs/${uid}`).get()).data()?.status, 'completed');
  assert.equal((await db.doc(`users/${uid}`).get()).exists, false);
  assert.equal((await bucket.file(`profile_images/${uid}.jpg`).exists())[0], false);
  await assert.rejects(auth.getUser(uid), { code: 'auth/user-not-found' });
  // Simulate completion of a previously started upload after the job finished.
  await bucket.file(`profile_images/${uid}.jpg`).save(Buffer.from('late synthetic upload'));
  const lateDeadline = Date.now() + 30000;
  while (Date.now() < lateDeadline) {
    if (!(await bucket.file(`profile_images/${uid}.jpg`).exists())[0]) break;
    await new Promise(resolve => setTimeout(resolve, 300));
  }
  assert.equal((await bucket.file(`profile_images/${uid}.jpg`).exists())[0], false);
});

test('actual moderator callables and cleanup trigger remove a match and redact a profile', {timeout:90000}, async()=>{
  const user=await auth.createUser({email:'moderator-e2e@example.invalid',password:'emulator-test-password'});
  await auth.setCustomUserClaims(user.uid,{moderator:true});
  const response=await fetch('http://127.0.0.1:9098/identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=emulator-only',{
    method:'POST',headers:{'Content-Type':'application/json'},
    body:JSON.stringify({email:'moderator-e2e@example.invalid',password:'emulator-test-password',returnSecureToken:true}),
  });
  const session=await response.json();
  assert.ok(session.idToken);
  await db.doc('users/mod-target').set({fullName:'Synthetic profile',avatarUrl:'https://example.invalid/photo'});
  await db.doc('matches/mod-game').set({createdBy:'mod-target',title:'Synthetic match'});
  await db.doc('notifications/mod-notice').set({matchId:'mod-game'});
  await bucket.file('profile_images/mod-target.jpg').save(Buffer.from('synthetic photo'));
  for(const [type,targetId,id,action] of [
    ['match','mod-game','b'.repeat(64),'removeMatch'],
    ['user','mod-target','c'.repeat(64),'redactProfile'],
  ]){
    await db.doc(`contentReports/${id}`).set({type,targetId,reason:'spam',status:'reviewing',reporterId:user.uid});
    const queue=await call('moderationQueue',session.idToken,{kind:'reports',after:''});
    const item=queue.result.items.find(item=>item.id===id);
    assert.ok(item.version);
    const result=await call('applyModerationAction',session.idToken,{reportId:id,action,version:item.version});
    assert.equal(result.result?.updated,true);
    const deadline=Date.now()+30000;
    while(Date.now()<deadline){
      if((await db.doc(`_moderationRemovals/${id}`).get()).get('status')==='completed')break;
      await new Promise(resolve=>setTimeout(resolve,300));
    }
    assert.equal((await db.doc(`_moderationRemovals/${id}`).get()).get('status'),'completed');
  }
  assert.equal((await db.doc('matches/mod-game').get()).exists,false);
  assert.equal((await db.doc('notifications/mod-notice').get()).exists,false);
  assert.equal((await db.doc('users/mod-target').get()).get('avatarUrl'),'');
  assert.equal((await bucket.file('profile_images/mod-target.jpg').exists())[0],false);
  const restored=await call('restoreModeratedAccount',session.idToken,{uid:'mod-target',reportId:'c'.repeat(64)});
  assert.equal(restored.result?.updated,true);
  assert.equal((await db.doc('_moderationAccounts/mod-target').get()).exists,false);
});
