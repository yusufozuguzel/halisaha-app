const { before, after, test } = require('node:test');
const assert = require('node:assert/strict');
const { createRequire } = require('node:module');
const serverRequire = createRequire(require.resolve('../functions/package.json'));
const { initializeApp, deleteApp } = serverRequire('firebase-admin/app');
const { getAuth } = serverRequire('firebase-admin/auth');
const { getFirestore } = serverRequire('firebase-admin/firestore');
let app, auth, db;
before(() => {
  if (process.env.GCLOUD_PROJECT !== 'demo-depar-review' ||
      process.env.FIRESTORE_EMULATOR_HOST !== '127.0.0.1:8088' ||
      process.env.FIREBASE_AUTH_EMULATOR_HOST !== '127.0.0.1:9098') throw new Error('Local demo only');
  app = initializeApp({projectId:'demo-depar-review'},'login-e2e');
  auth = getAuth(app); db = getFirestore(app);
});
after(async () => { if (app) await deleteApp(app); });
async function call(name, data) {
  const response = await fetch(`http://127.0.0.1:5008/demo-depar-review/europe-west1/${name}`, {
    method:'POST', headers:{'Content-Type':'application/json'}, body:JSON.stringify({data}),
    signal:AbortSignal.timeout(20000),
  });
  return response.json();
}
test('real callable accepts anonymous password verification, rejects wrong password and hides reset identity', {timeout:60000}, async () => {
  const password = 'Synthetic Callable 29!';
  const user = await auth.createUser({email:'callable@example.invalid',password});
  await db.doc(`users/${user.uid}`).set({name:'callable-player',profileVersion:2});
  assert.deepEqual(await call('verifyUsernamePassword',{username:'callable-player',password}),
    {result:{email:'callable@example.invalid'}});
  assert.equal((await call('verifyUsernamePassword',{username:'callable-player',password:'wrong'})).error.status,'UNAUTHENTICATED');
  assert.deepEqual(await call('resetUsernamePassword',{username:'callable-player'}),{result:{accepted:true}});
  assert.deepEqual(await call('resetUsernamePassword',{username:'absent-player'}),{result:{accepted:true}});
});
