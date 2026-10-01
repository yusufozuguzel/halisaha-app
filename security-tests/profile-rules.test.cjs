const { before, after, beforeEach, test } = require('node:test');
const assert = require('node:assert/strict');
const { readFileSync } = require('node:fs');
const { initializeTestEnvironment, assertSucceeds, assertFails } = require('@firebase/rules-unit-testing');
const { doc, setDoc, getDoc, getDocs, updateDoc, deleteDoc, collection, query, where, limit, serverTimestamp, writeBatch } = require('firebase/firestore');
let env;
before(async () => {
  if (process.env.GCLOUD_PROJECT !== 'demo-depar-review' || process.env.FIRESTORE_EMULATOR_HOST !== '127.0.0.1:8088') throw new Error('Local demo only');
  const rules = readFileSync('../functions/rules/firestore.candidate.rules', 'utf8');
  env = await initializeTestEnvironment({projectId:'demo-depar-profiles',firestore:{host:'127.0.0.1',port:8088,
    rules,
  }});
});
after(async () => { if (env) await env.cleanup(); });
const client = uid => env.authenticatedContext(uid).firestore();
async function seed(data) { await env.withSecurityRulesDisabled(async c => {
  const db = c.firestore();
  for (const [path,value] of Object.entries(data)) await setDoc(doc(db,path),value);
}); }
beforeEach(async () => {
  await env.clearFirestore();
  await seed({
    'users/alice':{uid:'alice',profileVersion:2,fullName:'Alice',blockedUsers:[]},
    'users/bob':{uid:'bob',profileVersion:2,fullName:'Bob',blockedUsers:[]},
    'users/legacy':{name:'Legacy',email:'private@example.invalid'},
    'users/alice/private/contact':{email:'private@example.invalid'},
    '_loginLimits/test':{count:1},
  });
});

test('anonymous get and search fail; authenticated users can read clean profiles only', async () => {
  const anon = env.unauthenticatedContext().firestore();
  await assertFails(getDoc(doc(anon,'users/alice')));
  await assertFails(getDocs(query(collection(anon,'users'),where('profileVersion','==',2),limit(20))));
  await assertSucceeds(getDoc(doc(client('bob'),'users/alice')));
  await assertFails(getDoc(doc(client('bob'),'users/legacy')));
  await assertSucceeds(getDoc(doc(client('legacy'),'users/legacy')));
  await assertSucceeds(getDoc(doc(client('new'),'users/new'))); // Profile setup can detect absence.
});

test('bounded profile search excludes legacy email documents; unconstrained queries fail', async () => {
  const users = collection(client('alice'),'users');
  const results = await assertSucceeds(getDocs(query(users,where('profileVersion','==',2),
    where('fullName','>=','A'),where('fullName','<=','A\uf8ff'),limit(20))));
  assert.equal(results.size, 1);
  assert.equal(results.docs[0].data().email, undefined);
  await assertFails(getDocs(query(users,limit(20))));
  await assertFails(getDocs(query(users,where('profileVersion','==',2))));
  await assertFails(getDocs(query(users,where('profileVersion','==',2),limit(100))));
});

test('registration and setup work but adding sensitive fields or roles is forbidden', async () => {
  const ref = doc(client('new'),'users/new');
  await assertSucceeds(setDoc(ref,{uid:'new',profileVersion:2,name:'Player',createdAt:serverTimestamp()}));
  await assertSucceeds(updateDoc(ref,{fullName:'Player',city:'İstanbul',position:'Forvet',preferredFoot:'Sağ',isProfileComplete:true,avatarType:'icon',avatarData:'0'}));
  for (const patch of [{email:'private@example.invalid'}, {phone:'123'}, {moderator:true}, {uid:'bob'}, {name:42},
    {fullName:'x'.repeat(101)}, {avatarUrl:'x'.repeat(2049)}, {blockedUsers:'bob'}, {profileVersion:1}]) {
    await assertFails(updateDoc(ref,patch));
  }
  await assertFails(updateDoc(doc(client('bob'),'users/new'),{fullName:'Forged'}));
  await assertFails(deleteDoc(ref));
});

test('legacy email cannot be marked public without removing it atomically', async () => {
  const ref = doc(client('legacy'),'users/legacy');
  await assertFails(updateDoc(ref,{profileVersion:2}));
  await assertSucceeds(setDoc(ref,{profileVersion:2,name:'Legacy'}));
  const result = await assertSucceeds(getDoc(doc(client('bob'),'users/legacy')));
  assert.equal(result.data().email, undefined);
});

test('private data and throttle records cannot be read or written by clients', async () => {
  for (const path of ['users/alice/private/contact','_loginLimits/test']) {
    await assertFails(getDoc(doc(client('alice'),path)));
    await assertFails(setDoc(doc(client('alice'),path),{count:0}));
  }
});

test('deletion barrier applies to profile writes and social block cleanup still works', async () => {
  const db = client('alice');
  const batch = writeBatch(db);
  batch.update(doc(db,'users/alice'),{blockedUsers:['bob']});
  batch.delete(doc(db,'users/alice/friends/bob'));
  batch.delete(doc(db,'users/bob/friends/alice'));
  await assertSucceeds(batch.commit());
  await seed({'accountDeletionJobs/alice':{status:'processing'}});
  await assertFails(updateDoc(doc(db,'users/alice'),{fullName:'Blocked'}));
});
