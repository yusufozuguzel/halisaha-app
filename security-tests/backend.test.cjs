const { test, before, beforeEach, after } = require('node:test');
const assert = require('node:assert/strict');
const { createRequire } = require('node:module');
const serverRequire = createRequire(require.resolve('../functions/package.json'));
const { initializeApp, deleteApp } = serverRequire('firebase-admin/app');
const { getFirestore } = serverRequire('firebase-admin/firestore');
const { getAuth } = serverRequire('firebase-admin/auth');
const { createSafetyService } = require('../functions/src/safety.cjs');
const { initializeTestEnvironment } = require('@firebase/rules-unit-testing');
let app, db, auth, env;
function request(uid, data = {}, claims = {}) {
  return { auth: { uid, token: { auth_time: Math.floor(Date.now() / 1000), ...claims } }, data };
}
function service(options = {}) {
  return createSafetyService({ db, auth, bucket: { getFiles: async () => [[]] },
    deletionEnabled: true, reportsEnabled: true, pageSize: 25, ...options });
}
before(async () => {
  if (process.env.GCLOUD_PROJECT !== 'demo-depar-review' ||
      process.env.FIRESTORE_EMULATOR_HOST !== '127.0.0.1:8088' ||
      process.env.FIREBASE_AUTH_EMULATOR_HOST !== '127.0.0.1:9098') throw new Error('Local demo emulators required');
  app = initializeApp({ projectId: 'demo-depar-review' }, 'backend-test');
  db = getFirestore(app); auth = getAuth(app);
  env = await initializeTestEnvironment({ projectId: 'demo-depar-review', firestore: { host: '127.0.0.1', port: 8088 } });
});
beforeEach(async () => {
  await env.clearFirestore();
  const users = await auth.listUsers();
  for (const user of users.users) await auth.deleteUser(user.uid);
});
after(async () => { if (env) await env.cleanup(); if (app) await deleteApp(app); });

test('deployment guard, old auth and forged UID fail without mutation', async () => {
  await assert.rejects(service({ deletionEnabled: false }).requestDeletion(request('alice')), { code: 'unavailable' });
  await assert.rejects(service().requestDeletion(request('alice', { uid: 'bob' })), { code: 'invalid-argument' });
  await assert.rejects(service().requestDeletion(request('alice', {}, { auth_time: 1 })), { code: 'failed-precondition' });
  await assert.rejects(service().requestDeletion({ data: {} }), { code: 'unauthenticated' });
  assert.equal((await db.collection('accountDeletionJobs').get()).empty, true);
});

test('cleanup spans pages, relations, orphan subcollections and match copies; Auth is last', async () => {
  await auth.createUser({ uid: 'alice' }); await auth.createUser({ uid: 'bob' });
  await db.doc('users/alice/private/example').set({ private: true }); // Parent deliberately absent.
  await db.doc('users/bob').set({ blockedUsers: ['alice', 'carol'], fullName: 'keep' });
  await db.doc('matches/owned').set({ createdBy: 'alice' });
  await db.doc('matches/owned/nested/data').set({ secret: true });
  await db.doc('matches/shared').set({ createdBy: 'bob', currentPlayers: ['alice', 'bob'], positions: { 1: 'alice', 2: 'bob' }, pendingPositions: { 3: { uid: 'alice', name: 'private' } } });
  for (let start = 0; start < 510; start += 100) {
    const batch = db.batch();
    for (let i = start; i < Math.min(start + 100, 510); i++) batch.set(db.doc(`users/bob/notifications/n${i}`), { senderUid: 'alice' });
    await batch.commit();
  }
  await db.doc('users/orphan/friends/alice').set({ uid: 'alice', name: 'private' });
  await db.doc('notifications/from-owned').set({ matchId: 'owned', senderId: 'bob' });
  await db.doc('notifications/keep').set({ receiverId: 'bob' });
  await db.doc('contentReports/old').set({ reporterId: 'alice' });
  await db.doc('contentReports/reviewed').set({ reporterId:'bob', reviewedBy:'alice', restoredBy:'alice' });
  await db.doc('_moderationAccounts/alice').set({reportId:'old'});
  await db.doc('_moderationRemovals/old').set({uid:'alice',status:'pending'});
  const events = [];
  const backend = service({
    bucket: { getFiles: async () => [[
      { name: 'profile_images/alice.jpg', delete: async () => { await auth.getUser('alice'); events.push('storage'); } },
      { name: 'profile_images/alice.jpg-other', delete: async () => { throw new Error('Wrong object'); } },
    ]] },
    auth: { deleteUser: async uid => { events.push('auth'); return auth.deleteUser(uid); } },
  });
  await backend.requestDeletion(request('alice'));
  await backend.requestDeletion(request('alice')); // Safe duplicate.
  assert.deepEqual(await backend.prepareDeletion(request('bob')), { ready:true });
  await backend.processDeletion('alice');
  await backend.processDeletion('alice'); // Safe worker replay.
  assert.deepEqual(events, ['storage', 'auth']);
  await assert.rejects(auth.getUser('alice'), { code: 'auth/user-not-found' });
  assert.equal((await auth.getUser('bob')).uid, 'bob');
  for (const path of ['users/alice/private/example', 'users/orphan/friends/alice', 'matches/owned/nested/data', 'notifications/from-owned', 'contentReports/old']) {
    assert.equal((await db.doc(path).get()).exists, false, path);
  }
  assert.equal((await db.collection('users/bob/notifications').get()).empty, true);
  assert.deepEqual((await db.doc('matches/shared').get()).data(), { createdBy: 'bob', currentPlayers: ['bob'], positions: { 2: 'bob' }, pendingPositions: {} });
  assert.deepEqual((await db.doc('users/bob').get()).data().blockedUsers, ['carol']);
  assert.equal((await db.doc('notifications/keep').get()).exists, true);
  assert.deepEqual((await db.doc('contentReports/reviewed').get()).data(),{reporterId:'bob'});
  assert.equal((await db.doc('_moderationAccounts/alice').get()).exists,false);
  assert.equal((await db.doc('_moderationRemovals/old').get()).exists,false);
  assert.equal((await db.doc('_safetyLocks/accountDeletion').get()).exists, false);
  assert.equal((await db.doc('_retiredMatches/owned').get()).exists, true);
  assert.equal((await db.doc('accountDeletionJobs/alice').get()).data().status, 'completed');
});

test('Storage error preserves Auth and only this account barrier; retry finishes from checkpoint', async () => {
  await auth.createUser({ uid: 'alice' });
  await auth.createUser({ uid: 'bob' });
  await db.doc('users/alice').set({ fullName: 'test' });
  let failing = true;
  const backend = service({ bucket: { getFiles: async () => [[{ name: 'profile_images/alice.jpg', delete: async () => {
    if (failing) throw Object.assign(new Error('injected'), { code: 403 });
  } }]] } });
  await backend.requestDeletion(request('alice'));
  await assert.rejects(backend.processDeletion('alice'));
  assert.equal((await auth.getUser('alice')).uid, 'alice');
  assert.equal((await db.doc('_safetyLocks/accountDeletion').get()).exists, false);
  assert.equal((await db.doc('accountDeletionJobs/alice').get()).exists, true);
  assert.deepEqual(await backend.requestDeletion(request('bob')), { accepted:true });
  await backend.processDeletion('bob');
  assert.equal((await db.doc('accountDeletionJobs/bob').get()).get('status'),'completed');
  await assert.rejects(auth.getUser('bob'), {code:'auth/user-not-found'});
  assert.equal((await auth.getUser('alice')).uid,'alice');
  assert.equal((await db.doc('accountDeletionJobs/alice').get()).data().stage, 'storage');
  failing = false;
  await backend.processDeletion('alice');
  await assert.rejects(auth.getUser('alice'), { code: 'auth/user-not-found' });
});

test('reports derive identity/time/status on server, deduplicate and throttle', async () => {
  const backend = service();
  await db.doc('users/target').set({ name: 'test' });
  await db.doc('matches/game').set({ title: 'test',createdBy:'target' });
  const data = { type: 'user', targetId: 'target', reason: 'spam' };
  await backend.submitReport(request('alice', data));
  await backend.submitReport(request('alice', data));
  await assert.rejects(backend.submitReport(request('alice', { ...data, reporterId: 'victim' })), { code: 'invalid-argument' });
  await assert.rejects(backend.submitReport(request('alice', { type: 'match', targetId: 'game', reason: 'other' })), { code: 'resource-exhausted' });
  const reports = await db.collection('contentReports').get();
  assert.equal(reports.size, 1);
  assert.equal(reports.docs[0].data().reporterId, 'alice');
  assert.equal(reports.docs[0].data().status, 'pending');
  assert.ok(reports.docs[0].data().createdAt.toMillis() > 0);
  await assert.rejects(backend.listReports(request('alice')), { code: 'permission-denied' });
  const reportId = reports.docs[0].id;
  await assert.rejects(backend.reviewReport(request('alice', { reportId, status: 'resolved' })), { code: 'permission-denied' });
  const moderator = data => request('mod', data, { moderator: true });
  assert.equal((await backend.listReports(moderator({}))).reports.length, 1);
  await assert.rejects(backend.reviewReport(moderator({ reportId, status: 'resolved' })), { code: 'failed-precondition' });
  await backend.reviewReport(moderator({ reportId, status: 'reviewing' }));
  await backend.reviewReport(moderator({ reportId, status: 'dismissed' }));
  assert.equal((await db.doc(`contentReports/${reportId}`).get()).data().reviewedBy, 'mod');
});

test('two account jobs are independent and concurrent workers preserve unrelated shared players', async () => {
  for (const uid of ['alice','bob','carol']) await auth.createUser({uid});
  await db.doc('matches/shared').set({createdBy:'carol',currentPlayers:['alice','bob','carol'],
    positions:{0:'alice',1:'bob',2:'carol'},pendingPositions:{},invitedPlayers:[]});
  const backend = service();
  await Promise.all(['alice','bob'].map(uid=>backend.requestDeletion(request(uid))));
  await Promise.all(['alice','bob'].map(uid=>backend.processDeletion(uid)));
  assert.deepEqual((await db.doc('matches/shared').get()).get('currentPlayers'),['carol']);
  assert.deepEqual((await db.doc('matches/shared').get()).get('positions'),{2:'carol'});
  for (const uid of ['alice','bob']) assert.equal((await db.doc(`accountDeletionJobs/${uid}`).get()).get('status'),'completed');
  assert.equal((await auth.getUser('carol')).uid,'carol');
});

test('cleanup re-reads a shared match after the scan snapshot instead of overwriting a later join', async () => {
  await auth.createUser({uid:'alice'});
  await db.doc('matches/shared').set({createdBy:'bob',currentPlayers:['alice','bob'],positions:{0:'alice',1:'bob'}});
  let injected = false;
  const wrapQuery = query => new Proxy(query,{get(target,key) {
    if (key === 'get') return async () => {
      const snapshot = await target.get();
      if (!injected) {
        injected = true;
        await db.doc('matches/shared').update({currentPlayers:['alice','bob','carol'],positions:{0:'alice',1:'bob',2:'carol'}});
      }
      return snapshot;
    };
    if (['orderBy','limit','startAfter'].includes(key)) return (...args)=>wrapQuery(target[key](...args));
    const value = Reflect.get(target,key); return typeof value === 'function' ? value.bind(target) : value;
  }});
  const wrappedDb = new Proxy(db,{get(target,key) {
    if (key === 'collection') return path => path === 'matches' ? wrapQuery(target.collection(path)) : target.collection(path);
    const value = Reflect.get(target,key); return typeof value === 'function' ? value.bind(target) : value;
  }});
  const backend = service({db:wrappedDb});
  await backend.requestDeletion(request('alice'));
  await backend.processDeletion('alice');
  assert.equal(injected,true);
  assert.deepEqual((await db.doc('matches/shared').get()).get('currentPlayers'),['bob','carol']);
  assert.deepEqual((await db.doc('matches/shared').get()).get('positions'),{1:'bob',2:'carol'});
});

test('report writes and reviews reject deleting endpoints but unrelated moderation keeps working', async () => {
  const backend = service();
  await db.doc('users/target').set({name:'Target'});
  await db.doc('users/other').set({name:'Other'});
  await db.doc('matches/owned').set({createdBy:'target'});
  await backend.submitReport(request('alice',{type:'user',targetId:'target',reason:'spam'}));
  const report = (await db.collection('contentReports').get()).docs[0];
  await backend.requestDeletion(request('target'));
  await assert.rejects(backend.submitReport(request('bob',{type:'user',targetId:'target',reason:'spam'})),{code:'unavailable'});
  await assert.rejects(backend.submitReport(request('bob',{type:'match',targetId:'owned',reason:'spam'})),{code:'unavailable'});
  await assert.rejects(backend.reviewReport(request('mod',{reportId:report.id,status:'reviewing'},{moderator:true})),{code:'unavailable'});
  await backend.submitReport(request('bob',{type:'user',targetId:'other',reason:'spam'}));
  const independent = (await db.collection('contentReports').get()).docs.find(doc=>doc.id!==report.id);
  await backend.reviewReport(request('mod',{reportId:independent.id,status:'reviewing'},{moderator:true}));
  await backend.requestDeletion(request('mod'));
  await assert.rejects(backend.reviewReport(request('mod',{reportId:independent.id,status:'resolved'},{moderator:true})),{code:'unavailable'});
  await assert.rejects(backend.listReports(request('mod',{}, {moderator:true})),{code:'unavailable'});
});

test('late upload cleanup uses account tombstone and exact bucket/path/generation; failure retries',async()=>{
  await db.doc('accountDeletionJobs/alice').set({status:'completed'});
  const deleted=[]; let failing=true;
  const backend=service({bucket:{name:'demo-bucket',file:(name,options)=>({delete:async()=>{
    if(failing)throw Object.assign(new Error('injected'),{code:503});
    deleted.push({name,...options});
  }})}});
  const object={name:'profile_images/alice.jpg',bucket:'demo-bucket',generation:'123'};
  for(const other of [{...object,bucket:'different'},{...object,name:'profile_images/bob.jpg'},
    {...object,name:'profile_images/alice.jpg-other'},{...object,name:'elsewhere/alice.jpg'}]) {
    await backend.removeLateProfileUpload(other);
  }
  await assert.rejects(backend.removeLateProfileUpload(object));
  failing=false;
  await backend.removeLateProfileUpload(object);
  assert.deepEqual(deleted,[{name:'profile_images/alice.jpg',generation:'123'}]);
});
