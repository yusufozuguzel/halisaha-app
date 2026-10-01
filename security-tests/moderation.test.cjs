const { before, beforeEach, after, test } = require('node:test');
const assert = require('node:assert/strict');
const { createRequire } = require('node:module');
const { readFileSync } = require('node:fs');
const { initializeTestEnvironment, assertFails, assertSucceeds } = require('@firebase/rules-unit-testing');
const { doc, getDoc, setDoc, updateDoc, serverTimestamp, Timestamp } = require('firebase/firestore');
const server = createRequire(require.resolve('../functions/package.json'));
const { initializeApp, deleteApp } = server('firebase-admin/app');
const { getFirestore } = server('firebase-admin/firestore');
const { createModerationService } = require('../functions/src/moderation.cjs');
const { createSafetyService } = require('../functions/src/safety.cjs');
let app, db, env, moderation, safety;
const req = (data, uid = 'mod', token = { moderator: true }) => ({ data, auth: { uid, token: { auth_time: Date.now()/1000, ...token } } });
const rid = 'a'.repeat(64);
const client = uid => env.authenticatedContext(uid).firestore();
before(async () => {
  if (process.env.GCLOUD_PROJECT !== 'demo-depar-review' || process.env.FIRESTORE_EMULATOR_HOST !== '127.0.0.1:8088') throw new Error('Local demo only');
  app = initializeApp({ projectId: 'demo-depar-moderation' }, 'moderation-test');
  db = getFirestore(app);
  env = await initializeTestEnvironment({ projectId: 'demo-depar-moderation', firestore: {
    host: '127.0.0.1', port: 8088, rules: readFileSync('../functions/rules/firestore.candidate.rules', 'utf8') } });
  moderation = createModerationService({ db, enabled: true });
  safety = createSafetyService({ db, auth: {}, bucket: {}, deletionEnabled: true, reportsEnabled: true });
});
beforeEach(async () => {
  await env.clearFirestore();
  for (const uid of ['alice','bob','mod']) await db.doc(`users/${uid}`).set({ profileVersion:2, fullName:uid, blockedUsers:[] });
  await db.doc(`contentReports/${rid}`).set({ type:'user', targetId:'alice', status:'reviewing', reporterId:'bob', reason:'spam' });
});
after(async () => { if (env) await env.cleanup(); if (app) await deleteApp(app); });
const first = async () => (await moderation.queue(req({kind:'reports',after:''}))).items[0];
const restrict = async () => moderation.act(req({reportId:rid,action:'restrictAccount',version:(await first()).version}));

test('only enabled recent moderators can read or act, never their own account', async () => {
  for (const request of [req({kind:'reports',after:''},'bob',{}), req({kind:'reports',after:''},'mod',{moderator:true,auth_time:1})]) {
    await assert.rejects(moderation.queue(request));
  }
  await assert.rejects(createModerationService({db}).queue(req({kind:'reports',after:''})), {code:'unavailable'});
  await db.doc(`contentReports/${rid}`).update({targetId:'mod'});
  await assert.rejects(moderation.act(req({reportId:rid,action:'restrictAccount',version:(await first()).version})), {code:'permission-denied'});
});

test('stale previews and wrong actions cannot mutate, retries are idempotent', async () => {
  const version = (await first()).version;
  await db.doc('users/alice').update({fullName:'changed'});
  await assert.rejects(moderation.act(req({reportId:rid,action:'restrictAccount',version})), {code:'failed-precondition'});
  await assert.rejects(moderation.act(req({reportId:rid,action:'removeMatch',version:(await first()).version})), {code:'failed-precondition'});
  const fresh = (await first()).version;
  await restrict();
  await moderation.act(req({reportId:rid,action:'restrictAccount',version:fresh}));
  assert.equal((await db.doc(`contentReports/${rid}`).get()).get('status'),'resolved');
  assert.equal((await db.doc('_moderationAccounts/alice').get()).get('reportId'),rid);
});

test('restriction stops stale-token writes, preserves others, reporting and account deletion', async () => {
  await restrict();
  const alice = client('alice'), bob = client('bob');
  await assertFails(updateDoc(doc(alice,'users/alice'),{fullName:'spoof'}));
  await assertFails(setDoc(doc(alice,'matches/new'),{createdBy:'alice',creatorId:'alice',title:'test',maxPlayers:10,
    date:Timestamp.fromMillis(Date.now()+86400000),createdAt:serverTimestamp(),status:'open',currentPlayers:['alice']}));
  await assertFails(setDoc(doc(alice,'users/bob/followRequests/alice'),{from:'alice',status:'pending',createdAt:serverTimestamp()}));
  await assertSucceeds(updateDoc(doc(bob,'users/bob'),{fullName:'active'}));
  await assertSucceeds(getDoc(doc(alice,'_moderationAccounts/alice')));
  await assertFails(getDoc(doc(bob,'_moderationAccounts/alice')));
  await assertFails(setDoc(doc(alice,'_moderationAccounts/alice'),{}));
  await safety.submitReport(req({type:'user',targetId:'bob',reason:'other'},'alice',{}));
  await safety.prepareDeletion(req({},'alice',{}));
  await safety.requestDeletion(req({},'alice',{}));
  assert.equal((await db.doc('accountDeletionJobs/alice').get()).exists,true);
});

test('restoration works after reporter deletion; a stale restore cannot lift a newer restriction', async () => {
  await restrict();
  await db.doc(`contentReports/${rid}`).delete();
  await assert.rejects(moderation.restore(req({uid:'alice',reportId:'b'.repeat(64)})),{code:'failed-precondition'});
  await moderation.restore(req({uid:'alice',reportId:rid}));
  await moderation.restore(req({uid:'alice',reportId:rid}));
  await assertSucceeds(updateDoc(doc(client('alice'),'users/alice'),{fullName:'restored'}));
});

test('match removal is atomic, prevents reuse and clears paginated invitation copies', async () => {
  await db.doc('matches/game').set({createdBy:'alice',title:'bad'});
  await db.doc('matches/game/private/old').set({value:1});
  await db.doc(`contentReports/${rid}`).update({type:'match',targetId:'game'});
  const batch=db.batch();
  for(let i=0;i<110;i++)batch.set(db.doc(`users/bob/notifications/n${i}`),{matchId:'game'});
  batch.set(db.doc('notifications/root'),{matchId:'game'});
  batch.set(db.doc('notifications/keep'),{matchId:'other'});
  await batch.commit();
  const data={reportId:rid,action:'removeMatch',version:(await first()).version};
  await moderation.act(req(data));
  await moderation.act(req(data));
  assert.equal((await db.doc('matches/game').get()).exists,false);
  assert.equal((await db.doc('_retiredMatches/game').get()).exists,true);
  await moderation.cleanupRemoval(rid);
  await moderation.cleanupRemoval(rid);
  assert.equal((await db.doc('matches/game/private/old').get()).exists,false);
  assert.equal((await db.collection('users/bob/notifications').get()).empty,true);
  assert.equal((await db.doc('notifications/root').get()).exists,false);
  assert.equal((await db.doc('notifications/keep').get()).exists,true);
  assert.equal((await db.doc(`_moderationRemovals/${rid}`).get()).get('status'),'completed');
});

test('queue pages do not strand reports beyond first fifty and previews omit private fields',async()=>{
  await db.doc('users/alice').update({email:'must-not-return@example.invalid'});
  const batch=db.batch();
  for(let i=0;i<55;i++)batch.set(db.doc(`contentReports/${String(i).padStart(64,'0')}`),{type:'user',targetId:'alice',status:'pending',reason:'spam',reporterId:'bob'});
  await batch.commit();
  const page=await moderation.queue(req({kind:'reports',after:''}));
  const tail=await moderation.queue(req({kind:'reports',after:page.next}));
  assert.equal(page.items.length,50); assert.equal(tail.items.length,6);
  assert.equal(new Set([...page.items,...tail.items].map(x=>x.id)).size,56);
  assert.equal(JSON.stringify(page).includes('must-not-return'),false);
});

test('restricted moderator cannot bypass write barrier using server administration',async()=>{
  await db.doc('_moderationAccounts/mod').set({reportId:rid});
  await assert.rejects(moderation.queue(req({kind:'reports',after:''})),{code:'permission-denied'});
  await assert.rejects(safety.reviewReport(req({reportId:rid,status:'dismissed'})),{code:'permission-denied'});
});

test('profile cleanup keeps restriction on Storage failure and can be retried before restoration',async()=>{
  let failing=true, deleted=false;
  const service=createModerationService({db,enabled:true,bucket:{getFiles:async()=>[[
    {name:'profile_images/alice.jpg',delete:async()=>{if(failing)throw new Error('Storage unavailable');deleted=true;}},
    {name:'profile_images/alice.jpg-other',delete:async()=>{throw new Error('Wrong file');}},
  ]]}});
  await db.doc('users/alice').update({avatarUrl:'https://example.invalid/photo',position:'bad',city:'bad'});
  await db.doc('users/bob/friends/alice').set({uid:'alice',fullName:'old',avatarUrl:'old'});
  await db.doc('users/bob/notifications/old').set({senderUid:'alice',senderName:'old'});
  await service.act(req({reportId:rid,action:'redactProfile',version:(await first()).version}));
  assert.equal((await db.doc('users/alice').get()).get('fullName'),'Kullanıcı');
  assert.equal((await db.doc('users/alice').get()).get('avatarUrl'),'');
  await assert.rejects(service.cleanupRemoval(rid));
  await assert.rejects(service.restore(req({uid:'alice',reportId:rid})),{code:'failed-precondition'});
  const second='d'.repeat(64);
  await db.doc(`contentReports/${second}`).set({type:'user',targetId:'alice',status:'reviewing',reason:'spam',reporterId:'bob'});
  await assert.rejects(service.act(req({reportId:second,action:'redactProfile',version:(await first()).version})),{code:'failed-precondition'});
  failing=false;
  await service.cleanupRemoval(rid);
  assert.equal(deleted,true);
  assert.equal((await db.doc('users/bob/friends/alice').get()).get('avatarUrl'),'');
  assert.equal((await db.doc('users/bob/notifications/old').get()).exists,false);
  await service.restore(req({uid:'alice',reportId:rid}));
  assert.equal((await db.doc('_moderationAccounts/alice').get()).exists,false);
});

test('a disappeared target can be dismissed without fabricating an applied action',async()=>{
  await db.doc('users/alice').delete();
  await safety.reviewReport(req({reportId:rid,status:'dismissed'}));
  assert.equal((await db.doc(`contentReports/${rid}`).get()).get('status'),'dismissed');
});

test('profile cleanup checkpoints a page and resumes after an interrupted social-copy scan',async()=>{
  const batch=db.batch();
  for(let i=0;i<110;i++)batch.set(db.doc(`users/bob/friends/copy${String(i).padStart(3,'0')}`),{uid:'alice',fullName:'old'});
  await batch.commit();
  await moderation.act(req({reportId:rid,action:'redactProfile',version:(await first()).version}));
  let gets=0;
  const wrap=query=>new Proxy(query,{get(target,key){
    if(key==='get')return async()=>{if(++gets===2)throw new Error('Synthetic page interruption');return target.get();};
    if(['orderBy','limit','startAfter'].includes(key))return(...args)=>wrap(target[key](...args));
    const value=Reflect.get(target,key);return typeof value==='function'?value.bind(target):value;
  }});
  const wrapped=new Proxy(db,{get(target,key){
    if(key==='collectionGroup')return name=>name==='friends'?wrap(target.collectionGroup(name)):target.collectionGroup(name);
    const value=Reflect.get(target,key);return typeof value==='function'?value.bind(target):value;
  }});
  const service=createModerationService({db:wrapped,enabled:true,bucket:{getFiles:async()=>[[]]}});
  await assert.rejects(service.cleanupRemoval(rid));
  const job=await db.doc(`_moderationRemovals/${rid}`).get();
  assert.equal(job.get('stage'),'friends');
  assert.equal(job.get('cursor'),'users/bob/friends/copy099');
  await service.cleanupRemoval(rid);
  const copies=await db.collection('users/bob/friends').get();
  assert.equal(copies.size,110);
  assert.equal(copies.docs.every(d=>d.get('fullName')==='Kullanıcı'),true);
  assert.equal((await db.doc(`_moderationRemovals/${rid}`).get()).get('status'),'completed');
});

test('the same reporter can report changed content after an earlier case was closed',async()=>{
  await db.doc(`contentReports/${rid}`).delete();
  const request=req({type:'user',targetId:'alice',reason:'spam'},'bob',{});
  await safety.submitReport(request);
  const first=(await db.collection('contentReports').get()).docs[0];
  await first.ref.update({status:'dismissed'});
  await safety.submitReport(request);
  assert.equal((await db.collection('contentReports').get()).size,1);
  await db.doc('users/alice').update({fullName:'changed content'});
  await assert.rejects(safety.submitReport(request),{code:'resource-exhausted'});
  await db.doc('_reportLimits/bob').delete(); // Advance past throttling for the synthetic scenario.
  await safety.submitReport(request);
  const reports=await db.collection('contentReports').get();
  assert.equal(reports.size,2);
  assert.equal(reports.docs.filter(d=>d.get('status')==='pending').length,1);
});
