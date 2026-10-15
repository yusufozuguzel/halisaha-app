// Independent, synthetic-only audit. Never points at a live Firebase project.
const {before, after, beforeEach, test} = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const {createRequire} = require('node:module');
const localRequire = createRequire(path.resolve(__dirname, '../../security-tests/package.json'));
const {initializeTestEnvironment, assertSucceeds, assertFails} = localRequire('@firebase/rules-unit-testing');
const {doc, collection, query, where, limit, getDoc, getDocs, setDoc, updateDoc,
  deleteDoc, writeBatch, Timestamp, serverTimestamp} = localRequire('firebase/firestore');
const {ref, uploadBytes, deleteObject, getBytes, updateMetadata} = localRequire('firebase/storage');
const root = path.resolve(__dirname, '../..');
const candidate = fs.readFileSync(path.join(root,'functions/rules/firestore.candidate.rules'),'utf8');
let env;
const client = (uid, verified=true) => env.authenticatedContext(uid,{email_verified:verified}).firestore();
const profile = uid => ({uid, profileVersion:2, fullName:uid, blockedUsers:[], createdAt:Timestamp.fromMillis(1000)});
const match = (patch={}) => ({title:'Audit fixture',venue:'Synthetic pitch',maxPlayers:14,
  date:Timestamp.fromMillis(Date.now()+86400000),endDate:Timestamp.fromMillis(Date.now()+90000000),
  createdBy:'alice',creatorId:'alice',createdAt:Timestamp.fromMillis(1000),status:'open',
  currentPlayers:['alice'],positions:{'0':'alice'},pendingPositions:{},invitedPlayers:[],formation:'',...patch});
const seed = data => env.withSecurityRulesDisabled(async c => {
  const db=c.firestore();
  for(const [p,d] of Object.entries(data)) await setDoc(doc(db,p),d);
});
before(async()=>{
  assert.equal(process.env.GCLOUD_PROJECT,'demo-depar-audit');
  assert.equal(process.env.FIRESTORE_EMULATOR_HOST,'127.0.0.1:8189');
  assert.equal(process.env.FIREBASE_STORAGE_EMULATOR_HOST,'127.0.0.1:9199');
  env=await initializeTestEnvironment({projectId:'demo-depar-audit',
    firestore:{host:'127.0.0.1',port:8189,rules:candidate},
    storage:{host:'127.0.0.1',port:9199,rules:fs.readFileSync(path.join(root,'functions/rules/storage.candidate.rules'),'utf8')}});
});
after(async()=>{if(env) await env.cleanup();});
beforeEach(async()=>{
  await env.clearFirestore(); await env.clearStorage();
  await seed({'users/alice':profile('alice'),'users/bob':profile('bob'),'users/mallory':profile('mallory'),
    'matches/game':match(),'_runtimePolicy/safety':{enabled:true}});
});

test('F1: owner publishes unscanned external avatar URL and another user reads it',async()=>{
  const url='https://audit-image.invalid/unscanned.jpg';
  await assertSucceeds(updateDoc(doc(client('alice'),'users/alice'),{avatarUrl:url}));
  const seen=await assertSucceeds(getDoc(doc(client('bob'),'users/alice')));
  assert.equal(seen.data().avatarUrl,url);
});

test('F2: blocked user and unrelated user can retrieve private block relationships',async()=>{
  await assertSucceeds(updateDoc(doc(client('alice'),'users/alice'),{blockedUsers:['bob']}));
  const blocked=await assertSucceeds(getDoc(doc(client('bob'),'users/alice')));
  assert.deepEqual(blocked.data().blockedUsers,['bob']);
  const all=await assertSucceeds(getDocs(query(collection(client('mallory'),'users'),where('profileVersion','==',2),limit(50))));
  assert.deepEqual(all.docs.find(d=>d.id==='alice').data().blockedUsers,['bob']);
});

test('F3a: one future match permits repeated profile invitations with arbitrary IDs, policy enabled',async()=>{
  const db=client('alice'); const m=(await getDoc(doc(db,'matches/game'))).data();
  for(let i=0;i<5;i++) await assertSucceeds(setDoc(doc(db,`users/bob/notifications/replay-${i}`),{
    type:'match_invite',fromUid:'alice',title:'Maç Daveti ⚽',message:'Seni "Audit fixture" maçına davet etti.',
    matchId:'game',matchTitle:m.title,matchDate:m.date,isRead:false,createdAt:serverTimestamp()}));
  const inbox=await getDocs(collection(client('bob'),'users/bob/notifications'));
  assert.equal(inbox.size,5);
});

test('F3b: one follow-request cooldown permit authorizes five notices in same batch',async()=>{
  const db=client('alice'); const b=writeBatch(db);
  b.set(doc(db,'_writeLimits/alice/actions/followRequest'),{targetId:'bob',updatedAt:serverTimestamp()});
  b.set(doc(db,'users/bob/followRequests/alice'),{from:'alice',status:'pending',createdAt:serverTimestamp()});
  for(let i=0;i<5;i++) b.set(doc(db,`users/bob/notifications/fanout-${i}`),{
    type:'follow_request',senderUid:'alice',senderName:'alice',title:'Yeni Takip İsteği 👥',
    message:'alice seninle arkadaş olmak istiyor.',status:'pending',isRead:false,createdAt:serverTimestamp()});
  await assertSucceeds(b.commit());
  assert.equal((await getDocs(collection(client('bob'),'users/bob/notifications'))).size,5);
});

test('F3c: an existing pending slot authorizes repeated formation notices without a roster mutation',async()=>{
  await seed({'matches/game':match({pendingPositions:{'1':'bob'},invitedPlayers:['bob']})});
  for(let i=0;i<3;i++) await assertSucceeds(setDoc(doc(client('alice'),`notifications/formation-${i}`),{
    type:'match_invite',senderId:'alice',receiverId:'bob',matchId:'game',positionId:'1',
    status:'pending',isRead:false,createdAt:serverTimestamp()}));
  for(let i=0;i<3;i++) assert.equal((await getDoc(doc(client('bob'),`notifications/formation-${i}`))).exists(),true);
});

test('F4: capacity-only update breaks roster and prevents innocent participant leaving',async()=>{
  const members=['alice','bob',...Array.from({length:10},(_,i)=>`fixture${i}`)];
  await seed({'matches/game':match({currentPlayers:members,positions:{}})});
  const leave={currentPlayers:members.filter(x=>x!=='bob'),positions:{},pendingPositions:{},invitedPlayers:[],
    slotChange:{from:'',to:'',pending:''}};
  await assertSucceeds(updateDoc(doc(client('alice'),'matches/game'),{maxPlayers:10}));
  assert.equal((await getDoc(doc(client('bob'),'matches/game'))).data().currentPlayers.length,12);
  await assertFails(updateDoc(doc(client('bob'),'matches/game'),leave));
  await assertSucceeds(updateDoc(doc(client('alice'),'matches/game'),{maxPlayers:14}));
  await assertSucceeds(updateDoc(doc(client('bob'),'matches/game'),leave));
});

test('controls: unauth profile, foreign profile, roles, ownership and friendship forgery are denied',async()=>{
  await assertFails(getDoc(doc(env.unauthenticatedContext().firestore(),'users/alice')));
  await assertFails(updateDoc(doc(client('mallory'),'users/alice'),{fullName:'forged'}));
  await assertFails(updateDoc(doc(client('alice'),'users/alice'),{moderator:true}));
  await assertFails(updateDoc(doc(client('mallory'),'matches/game'),{createdBy:'mallory',creatorId:'mallory'}));
  await assertFails(setDoc(doc(client('mallory'),'users/alice/friends/mallory'),{
    uid:'mallory',fullName:'mallory',avatarUrl:'',avatarData:'0',position:'',since:serverTimestamp()}));
});

test('controls: one-sided friendship cannot reveal social lists; actual block batch revokes list access',async()=>{
  const friend=uid=>({uid,fullName:uid,avatarUrl:'',avatarData:'0',position:'',since:Timestamp.fromMillis(1000)});
  await seed({'users/alice/friends/bob':friend('bob'),'users/alice/friends/mallory':friend('mallory')});
  await assertFails(getDocs(collection(client('bob'),'users/alice/friends')));
  await seed({'users/bob/friends/alice':friend('alice')});
  await assertSucceeds(getDocs(collection(client('bob'),'users/alice/friends')));
  const db=client('alice'),b=writeBatch(db);
  b.update(doc(db,'users/alice'),{blockedUsers:['bob']});
  b.delete(doc(db,'users/alice/friends/bob')); b.delete(doc(db,'users/bob/friends/alice'));
  await assertSucceeds(b.commit());
  await assertFails(getDocs(collection(client('bob'),'users/alice/friends')));
});

test('controls: blocked follow and unverified invite denied even with valid-looking payload',async()=>{
  await seed({'users/bob':{...profile('bob'),blockedUsers:['alice']}});
  const db=client('alice'),b=writeBatch(db);
  b.set(doc(db,'_writeLimits/alice/actions/followRequest'),{targetId:'bob',updatedAt:serverTimestamp()});
  b.set(doc(db,'users/bob/followRequests/alice'),{from:'alice',status:'pending',createdAt:serverTimestamp()});
  await assertFails(b.commit());
  await seed({'users/bob':profile('bob'),'matches/game':match({pendingPositions:{'1':'bob'},invitedPlayers:['bob']})});
  await assertFails(setDoc(doc(client('alice',false),'notifications/unverified'),{
    type:'match_invite',senderId:'alice',receiverId:'bob',matchId:'game',positionId:'1',
    status:'pending',isRead:false,createdAt:serverTimestamp()}));
});

test('controls: candidate Storage rejects owner upload, metadata overwrite and foreign deletion',async()=>{
  const obj=uid=>ref(env.authenticatedContext(uid).storage(),'profile_images/alice.jpg');
  await assertFails(uploadBytes(obj('alice'),new Uint8Array([1,2,3]),{contentType:'image/jpeg'}));
  await env.withSecurityRulesDisabled(c=>uploadBytes(ref(c.storage(),'profile_images/alice.jpg'),new Uint8Array([1,2,3]),{contentType:'image/jpeg'}));
  await assertFails(updateMetadata(obj('alice'),{contentType:'image/png'}));
  await assertFails(deleteObject(obj('bob')));
  await assertFails(getBytes(ref(env.unauthenticatedContext().storage(),'profile_images/alice.jpg')));
});

test('H1: SHA-matched historical Storage lets owner publish arbitrary bytes labelled JPEG',async()=>{
  const historical=fs.readFileSync(path.join(__dirname,'historical-deployed.storage.rules'),'utf8');
  assert.equal(require('node:crypto').createHash('sha256').update(historical).digest('hex'),
    '1e223e061a0cacff01a115dec314e4cf342f0b4688617b47d3ef1bf29b1ba5c5');
  const h=await initializeTestEnvironment({projectId:'demo-depar-audit',storage:{host:'127.0.0.1',port:9199,rules:historical}});
  try {
    const bytes=Buffer.from('synthetic non-image payload');
    await assertSucceeds(uploadBytes(ref(h.authenticatedContext('alice').storage(),'profile_images/alice.jpg'),bytes,{contentType:'image/jpeg'}));
    const seen=await assertSucceeds(getBytes(ref(h.authenticatedContext('bob').storage(),'profile_images/alice.jpg')));
    assert.equal(Buffer.from(seen).toString(),bytes.toString());
  } finally {await h.cleanup();}
});
