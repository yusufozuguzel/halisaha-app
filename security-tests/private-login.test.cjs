const { before, after, beforeEach, test } = require('node:test');
const assert = require('node:assert/strict');
const { createRequire } = require('node:module');
const serverRequire = createRequire(require.resolve('../functions/package.json'));
const { initializeApp, deleteApp } = serverRequire('firebase-admin/app');
const { getFirestore } = serverRequire('firebase-admin/firestore');
const { getAuth } = serverRequire('firebase-admin/auth');
const { createPrivateLogin, createAuthRest } = require('../functions/src/private-login.cjs');
const { createUsernameService } = require('../functions/src/usernames.cjs');
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

test('claimed handles take priority over display-name aliases and resolve to the claimed Auth account', async () => {
  await migrateProfiles({db,auth,apply:true});
  await auth.createUser({uid:'bob', email:'bob@example.invalid', password:'Different Synthetic 21!'});
  await db.doc('users/bob').set({profileVersion:2,fullName:'player',name:'other'});
  const usernames = createUsernameService({db,enabled:true});
  assert.deepEqual(await usernames.claim({auth:{uid:'alice'},data:{username:'player'}}), {username:'player'});
  assert.deepEqual(await service().verifyUsernamePassword(call({username:'player',password})), {email:'alice@example.invalid'});
  assert.deepEqual(await usernames.find({auth:{uid:'bob'},data:{username:'player'}}), {
    available:false, uid:'alice', displayName:'player',
  });
  assert.deepEqual(await usernames.find({auth:{uid:'bob'},data:{username:'free_name'}}), {available:true});
});

test('legacy login rejects ambiguity across fullName and name aliases', async () => {
  await auth.createUser({uid:'bob', email:'bob@example.invalid', password:'Different Synthetic 21!'});
  await db.doc('users/bob').set({name:'player'});
  await assert.rejects(service().verifyUsernamePassword(call({username:'player',password})), {code:'unauthenticated'});
});

test('username claims are unique, immutable, lowercase-only, and rejected for deleting or unready profiles', async () => {
  await migrateProfiles({db,auth,apply:true});
  const usernames = createUsernameService({db,enabled:true});
  await assert.rejects(usernames.claim({auth:{uid:'alice'},data:{username:'Player'}}), {code:'invalid-argument'});
  await assert.rejects(usernames.claim({auth:{uid:'alice'},data:{username:'player',uid:'alice'}}), {code:'invalid-argument'});
  await usernames.claim({auth:{uid:'alice'},data:{username:'player'}});
  await assert.rejects(usernames.claim({auth:{uid:'alice'},data:{username:'different'}}), {code:'failed-precondition'});
  await assert.rejects(usernames.claim({auth:{uid:'bob'},data:{username:'player'}}), {code:'failed-precondition'});
  await auth.createUser({uid:'bob', email:'bob@example.invalid', password:'Different Synthetic 21!'});
  await db.doc('users/bob').set({profileVersion:2,fullName:'Bob'});
  await assert.rejects(usernames.claim({auth:{uid:'bob'},data:{username:'player'}}), {code:'already-exists'});
  await db.doc('accountDeletionJobs/alice').set({status:'processing'});
  await assert.rejects(usernames.claim({auth:{uid:'alice'},data:{username:'player'}}), {code:'failed-precondition'});
  assert.equal((await db.doc('_usernames/player').get()).get('uid'), 'alice');
});

test('concurrent claims for one handle commit exactly one owner and profile', async () => {
  await migrateProfiles({db,auth,apply:true});
  await auth.createUser({uid:'bob', email:'bob@example.invalid', password:'Different Synthetic 21!'});
  await db.doc('users/bob').set({profileVersion:2,fullName:'Bob'});
  const usernames = createUsernameService({db,enabled:true});
  const outcomes = await Promise.allSettled([
    usernames.claim({auth:{uid:'alice'},data:{username:'shared_handle'}}),
    usernames.claim({auth:{uid:'bob'},data:{username:'shared_handle'}}),
  ]);
  const winners = outcomes.flatMap((outcome, index) => outcome.status === 'fulfilled' ? [index] : []);
  const losers = outcomes.filter(outcome => outcome.status === 'rejected');
  assert.equal(winners.length, 1);
  assert.equal(losers.length, 1);
  assert.equal(losers[0].reason.code, 'already-exists');
  const winnerUid = winners[0] === 0 ? 'alice' : 'bob';
  const loserUid = winnerUid === 'alice' ? 'bob' : 'alice';
  assert.equal((await db.doc('_usernames/shared_handle').get()).get('uid'), winnerUid);
  assert.equal((await db.doc(`users/${winnerUid}`).get()).get('username'), 'shared_handle');
  assert.equal((await db.doc(`users/${loserUid}`).get()).get('username'), undefined);
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
  const stored = (await db.collection('_loginLimits').get()).docs;
  assert.equal(stored.length, 2);
  for (const doc of stored) {
    assert.match(doc.id, /^[a-f0-9]{64}$/);
    assert.deepEqual(Object.keys(doc.data()).sort(), ['count','expiresAt']);
  }
  // A different source gets its own username bucket; it has not hit its IP cap.
  await assert.rejects(backend.verifyUsernamePassword(call({username:'absent',password},'127.0.0.99')), {code:'unauthenticated'});
});

test('a login-name cap is scoped to the source IP while each IP still has a shared cap', async () => {
  const backend = service();
  for (let i = 0; i < 10; i++) {
    await assert.rejects(backend.verifyUsernamePassword(call({username:'target',password}, '198.51.100.10')), {code:'unauthenticated'});
  }
  await assert.rejects(backend.verifyUsernamePassword(call({username:'target',password}, '198.51.100.10')), {code:'resource-exhausted'});
  // The same displayed name is not globally locked by the first address.
  await assert.rejects(backend.verifyUsernamePassword(call({username:'target',password}, '198.51.100.11')), {code:'unauthenticated'});

  for (let i = 0; i < 39; i++) {
    await assert.rejects(backend.verifyUsernamePassword(call({username:`other-${i}`,password}, '198.51.100.11')), {code:'unauthenticated'});
  }
  await assert.rejects(backend.verifyUsernamePassword(call({username:'another-name',password}, '198.51.100.11')), {code:'resource-exhausted'});
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

test('migration removes only the two retired derived counters alongside profile email', async () => {
  await db.doc('users/alice').update({profileVersion:2, followersCount:8, followingCount:3});
  await db.doc('users/unknown').set({email:'private@example.invalid', followersCount:12, legacyScore:99});

  const dry = await migrateProfiles({db,auth});
  assert.equal(dry.ready, 1);
  assert.equal(dry.unknownFields, 1);
  assert.equal(dry.unchanged, 0);

  const applied = await migrateProfiles({db,auth,apply:true});
  assert.equal(applied.migrated, 1);
  const migrated = (await db.doc('users/alice').get()).data();
  assert.equal(migrated.email, undefined);
  assert.equal(migrated.followersCount, undefined);
  assert.equal(migrated.followingCount, undefined);
  assert.equal(migrated.profileVersion, 2);

  const unknown = (await db.doc('users/unknown').get()).data();
  assert.equal(unknown.followersCount, 12);
  assert.equal(unknown.legacyScore, 99);
  assert.equal(unknown.email, 'private@example.invalid');
});

test('migration stale-update guard preserves a concurrent profile change and all legacy fields', async () => {
  await db.doc('users/alice').update({followersCount:8, followingCount:3});
  let served = false;
  const racingDb = {
    collection(name) {
      return {
        orderBy() { return this; },
        limit() { return this; },
        startAfter() { return this; },
        async get() {
          if (served) return {empty:true, docs:[]};
          served = true;
          const page = await db.collection(name).get();
          return {empty:page.empty, docs:page.docs.map(doc => ({
            id:doc.id,
            data:() => doc.data(),
            updateTime:doc.updateTime,
            ref:{update:async (patch, precondition) => {
              await doc.ref.update({fullName:'concurrent profile edit'});
              return doc.ref.update(patch, precondition);
            }},
          }))};
        },
      };
    },
  };

  const counts = await migrateProfiles({db:racingDb,auth,apply:true});
  assert.equal(counts.migrated, 0);
  assert.equal(counts.changedDuringRun, 1);
  const profile = (await db.doc('users/alice').get()).data();
  assert.equal(profile.fullName, 'concurrent profile edit');
  assert.equal(profile.email, 'forged@example.invalid');
  assert.equal(profile.followersCount, 8);
  assert.equal(profile.followingCount, 3);
});
