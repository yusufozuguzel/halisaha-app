const { before, after, beforeEach, test } = require('node:test');
const assert = require('node:assert/strict');
const { createRequire } = require('node:module');
const serverRequire = createRequire(require.resolve('../functions/package.json'));
const { initializeApp, deleteApp } = serverRequire('firebase-admin/app');
const { getFirestore } = serverRequire('firebase-admin/firestore');
const { getAuth } = serverRequire('firebase-admin/auth');
const { createPrivateLogin, createAuthRest } = require('../functions/src/private-login.cjs');
const { migrateProfiles } = require('../functions/src/profile-migration.cjs');
const { initializeTestEnvironment } = require('@firebase/rules-unit-testing');
let app, db, auth, env;
const password = 'Synthetic Test 19!';
const call = (data, ip = '127.0.0.10') => ({ data, rawRequest: { ip } });
const rest = createAuthRest({ apiKey:'demo-only', emulatorHost:'127.0.0.1:9098' });
const service = (extra = {}) => createPrivateLogin({ db, auth, authRest:rest,
  enabled:true, rateKey:'local-emulator-only-key-at-least-32-characters', ...extra });

before(async () => {
  if (process.env.GCLOUD_PROJECT !== 'demo-depar-review' ||
      process.env.FIRESTORE_EMULATOR_HOST !== '127.0.0.1:8088' ||
      process.env.FIREBASE_AUTH_EMULATOR_HOST !== '127.0.0.1:9098') throw new Error('Local demo only');
  app = initializeApp({ projectId:'demo-depar-review' }, 'private-login-test');
  db = getFirestore(app); auth = getAuth(app);
  env = await initializeTestEnvironment({ projectId:'demo-depar-review', firestore:{host:'127.0.0.1',port:8088} });
});
after(async () => { if (env) await env.cleanup(); if (app) await deleteApp(app); });
beforeEach(async () => {
  await env.clearFirestore();
  for (const user of (await auth.listUsers()).users) await auth.deleteUser(user.uid);
  await auth.createUser({uid:'alice', email:'alice@example.invalid', password});
  await db.doc('users/alice').set({fullName:'player', name:'legacy', email:'forged@example.invalid'});
});

test('password is verified by real Auth emulator and profile email is never trusted', async () => {
  assert.deepEqual(await service().verifyUsernamePassword(call({username:'player',password})), {email:'alice@example.invalid'});
  const result = await rest('signInWithPassword', {email:'alice@example.invalid',password,returnSecureToken:true});
  assert.equal((await auth.verifyIdToken(result.idToken)).uid, 'alice');
  await assert.rejects(service().verifyUsernamePassword(call({username:'player',password:'wrong'})), {code:'unauthenticated'});
  await assert.rejects(service().verifyUsernamePassword(call({username:'player',password:` ${password} `})), {code:'unauthenticated'});
});

test('unknown, duplicate, disabled and deleting accounts all fail with the same error', async () => {
  const login = name => service().verifyUsernamePassword(call({username:name,password}));
  await assert.rejects(login('unknown'), {code:'unauthenticated'});
  await db.doc('users/bob').set({fullName:'player'});
  await assert.rejects(login('player'), {code:'unauthenticated'});
  await db.doc('users/bob').delete();
  await auth.updateUser('alice', {disabled:true});
  await assert.rejects(login('player'), {code:'unauthenticated'});
  await auth.updateUser('alice', {disabled:false});
  await db.doc('accountDeletionJobs/alice').set({status:'processing'});
  await assert.rejects(login('player'), {code:'unauthenticated'});
});

test('fullName precedes legacy name and both work after profile email removal', async () => {
  const counts = await migrateProfiles({db,auth,apply:true});
  assert.equal(counts.migrated, 1);
  assert.equal((await db.doc('users/alice').get()).get('email'), undefined);
  for (const username of ['player','legacy']) {
    assert.deepEqual(await service().verifyUsernamePassword(call({username,password})), {email:'alice@example.invalid'});
  }
  await auth.createUser({uid:'bob',email:'bob@example.invalid',password:'Different Synthetic 21!'});
  await db.doc('users/bob').set({fullName:'legacy'});
  await assert.rejects(service().verifyUsernamePassword(call({username:'legacy',password})), {code:'unauthenticated'});
});

test('reset returns identical acknowledgement and does not return email, tokens or links', async () => {
  assert.deepEqual(await service().resetUsernamePassword(call({username:'player'})), {accepted:true});
  assert.deepEqual(await service().resetUsernamePassword(call({username:'unknown'})), {accepted:true});
  await db.doc('users/bob').set({fullName:'player'});
  assert.deepEqual(await service().resetUsernamePassword(call({username:'player'})), {accepted:true});
});

test('rate limits use atomic shared buckets; stored data has no identifiers or credentials', async () => {
  const backend = service();
  const outcomes = await Promise.allSettled(Array.from({length:12}, () =>
    backend.verifyUsernamePassword(call({username:'absent',password}))));
  assert.equal(outcomes.filter(r => r.reason?.code === 'unauthenticated').length, 10);
  assert.equal(outcomes.filter(r => r.reason?.code === 'resource-exhausted').length, 2);
  await assert.rejects(backend.verifyUsernamePassword(call({username:'absent',password},'127.0.0.99')), {code:'resource-exhausted'});
  const stored = (await db.collection('_loginLimits').get()).docs;
  assert.equal(stored.length, 2);
  for (const doc of stored) {
    assert.match(doc.id, /^[a-f0-9]{64}$/);
    assert.deepEqual(Object.keys(doc.data()).sort(), ['count','expiresAt']);
  }
});

test('disabled config, forged UID, malformed fields and missing IP fail closed', async () => {
  const request = call({username:'player',password});
  await assert.rejects(service({enabled:false}).verifyUsernamePassword(request), {code:'unavailable'});
  await assert.rejects(service({rateKey:''}).verifyUsernamePassword(request), {code:'unavailable'});
  await assert.rejects(service().verifyUsernamePassword(call({...request.data,uid:'alice'})), {code:'invalid-argument'});
  await assert.rejects(service().verifyUsernamePassword({data:request.data}), {code:'unavailable'});
  await assert.rejects(service().resetUsernamePassword(call({username:'player',email:'forged@example.invalid'})), {code:'invalid-argument'});
  assert.equal((await db.collection('_loginLimits').get()).size, 0);
});

test('MFA challenge and mismatched verified UID cannot disclose email or bypass Auth', async () => {
  for (const result of [{mfaPendingCredential:'fake'}, {idToken:'fake',localId:'bob'}, {error:{message:'INVALID_PASSWORD'}}]) {
    await assert.rejects(service({authRest:async () => result}).verifyUsernamePassword(call({username:'player',password})), {code:'unauthenticated'});
  }
});

test('migration dry run is read-only, skips unknown data and is restartable', async () => {
  await db.doc('users/unknown').set({email:'private@example.invalid',phone:'keep for review'});
  await db.doc('users/invalid').set({name:42});
  await db.doc('users/orphan').set({name:'No Auth'});
  const before = (await db.doc('users/alice').get()).data();
  const dry = await migrateProfiles({db,auth,pageSize:2});
  assert.equal(dry.ready, 1); assert.equal(dry.unknownFields, 1);
  assert.equal(dry.invalidShape, 1); assert.equal(dry.missingAuth, 1);
  assert.deepEqual((await db.doc('users/alice').get()).data(), before);
  assert.equal((await migrateProfiles({db,auth,apply:true,pageSize:2})).migrated, 1);
  assert.equal((await migrateProfiles({db,auth,apply:true,pageSize:2})).unchanged, 1);
  assert.equal((await db.doc('users/unknown').get()).get('phone'), 'keep for review');
});
