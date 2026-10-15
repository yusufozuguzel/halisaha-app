const { before, after, beforeEach, test } = require('node:test');
const assert = require('node:assert/strict');
const { readFileSync } = require('node:fs');
const { initializeTestEnvironment, assertSucceeds, assertFails } = require('@firebase/rules-unit-testing');
const { doc, setDoc, deleteDoc, writeBatch, serverTimestamp, Timestamp } = require('firebase/firestore');

let env;
before(async () => {
  if (process.env.GCLOUD_PROJECT !== 'demo-depar-review' || process.env.FIRESTORE_EMULATOR_HOST !== '127.0.0.1:8088') {
    throw new Error('Local demo emulator required');
  }
  env = await initializeTestEnvironment({ projectId:'demo-depar-cooldowns', firestore:{
    host:'127.0.0.1', port:8088, rules:readFileSync('../functions/rules/firestore.candidate.rules','utf8'),
  } });
});
after(async () => { if (env) await env.cleanup(); });
beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async context => {
    const db = context.firestore();
    for (const uid of ['alice','bob','carol']) await setDoc(doc(db,`users/${uid}`),{profileVersion:2,fullName:uid,blockedUsers:[]});
    await setDoc(doc(db,'_runtimePolicy/safety'),{enabled:true});
  });
});
const client = (uid, verified = true) => env.authenticatedContext(uid,{email_verified:verified}).firestore();
function matchPayload(uid = 'alice') {
  const date = Timestamp.fromMillis(Date.now()+86_400_000);
  return { title:'Evening game',venue:'Park',price:0,maxPlayers:10,date,
    createdBy:uid,creatorId:uid,createdAt:serverTimestamp(),status:'open',currentPlayers:[uid] };
}
function matchBatch(db, id, stampTarget = id, uid = 'alice') {
  const batch = writeBatch(db);
  batch.set(doc(db,`matches/${id}`),matchPayload(uid));
  batch.set(doc(db,`_writeLimits/${uid}/actions/matchCreate`),{targetId:stampTarget,updatedAt:serverTimestamp()});
  return batch;
}
function followBatch(db, receiver, stampTarget = receiver) {
  const batch = writeBatch(db);
  batch.set(doc(db,`users/${receiver}/followRequests/alice`),{from:'alice',status:'pending',createdAt:serverTimestamp()});
  batch.set(doc(db,`users/${receiver}/notifications/alice`),{
    type:'follow_request',senderUid:'alice',senderName:'alice',title:'Yeni Takip İsteği 👥',
    message:'alice seninle arkadaş olmak istiyor.',status:'pending',isRead:false,createdAt:serverTimestamp(),
  });
  batch.set(doc(db,'_writeLimits/alice/actions/followRequest'),{targetId:stampTarget,updatedAt:serverTimestamp()});
  return batch;
}

test('enabled policy requires a verified email and one same-batch match creation stamp', async () => {
  const alice = client('alice');
  await assertSucceeds(matchBatch(alice,'first').commit());
  await assertFails(setDoc(doc(alice,'matches/no-stamp'),matchPayload()));
  const bob = client('bob');
  await assertSucceeds(matchBatch(bob,'verified-bob','verified-bob','bob').commit());
  const carol = client('carol',false);
  await assertFails(matchBatch(carol,'unverified-carol','unverified-carol','carol').commit());
  await assertFails(setDoc(doc(alice,'_writeLimits/alice/actions/matchCreate'),{
    targetId:'standalone',updatedAt:serverTimestamp(),
  }));
});

test('match cooldown stamp is bound to one new match and cannot be spoofed or reset', async () => {
  const alice = client('alice');
  const multi = writeBatch(alice);
  multi.set(doc(alice,'matches/one'),matchPayload());
  multi.set(doc(alice,'matches/two'),matchPayload());
  multi.set(doc(alice,'_writeLimits/alice/actions/matchCreate'),{targetId:'one',updatedAt:serverTimestamp()});
  await assertFails(multi.commit());
  const future = writeBatch(alice);
  future.set(doc(alice,'matches/future'),matchPayload());
  future.set(doc(alice,'_writeLimits/alice/actions/matchCreate'),{
    targetId:'future',updatedAt:Timestamp.fromMillis(Date.now()+60_000),
  });
  await assertFails(future.commit());
  await assertFails(deleteDoc(doc(alice,'_writeLimits/alice/actions/matchCreate')));

  await assertSucceeds(matchBatch(alice,'first').commit());
  await assertFails(matchBatch(alice,'second').commit());
  await env.withSecurityRulesDisabled(async context => {
    await setDoc(doc(context.firestore(),'_writeLimits/alice/actions/matchCreate'),{
      targetId:'previous',updatedAt:Timestamp.fromMillis(Date.now()-61_000),
    });
  });
  await assertSucceeds(matchBatch(alice,'after-cooldown').commit());
});

test('follow cooldown binds receiver and blocks rapid delete/recreation; unverified acceptance and deletion remain available', async () => {
  const alice = client('alice');
  await assertSucceeds(followBatch(alice,'bob').commit());
  await assertFails(followBatch(alice,'carol').commit());
  const bob = client('bob',false);
  const accept = writeBatch(bob);
  for (const [owner,friend,name] of [['bob','alice','alice'],['alice','bob','bob']]) {
    accept.set(doc(bob,`users/${owner}/friends/${friend}`),{uid:friend,fullName:name,avatarUrl:'',avatarData:'0',position:'',since:serverTimestamp()});
  }
  accept.delete(doc(bob,'users/bob/followRequests/alice'));
  await assertSucceeds(accept.commit());
  await assertSucceeds(deleteDoc(doc(alice,'users/alice/notifications/alice')));
  await assertFails(followBatch(alice,'bob').commit());
  await assertFails(followBatch(alice,'bob').commit());
  await assertFails(deleteDoc(doc(alice,'_writeLimits/alice/actions/followRequest')));
});

test('disabled or absent policy keeps legacy match creation available without limiter state', async () => {
  await env.withSecurityRulesDisabled(async context => {
    await deleteDoc(doc(context.firestore(),'_runtimePolicy/safety'));
  });
  const unverified = client('alice',false);
  await assertSucceeds(setDoc(doc(unverified,'matches/legacy'),matchPayload()));
  await env.withSecurityRulesDisabled(async context => {
    await setDoc(doc(context.firestore(),'_runtimePolicy/safety'),{enabled:false});
  });
  await assertSucceeds(setDoc(doc(unverified,'matches/legacy2'),matchPayload()));
});
