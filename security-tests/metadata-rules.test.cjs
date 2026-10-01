const { before, after, beforeEach, test } = require('node:test');
const assert = require('node:assert/strict');
const { readFileSync } = require('node:fs');
const { initializeTestEnvironment, assertSucceeds, assertFails } = require('@firebase/rules-unit-testing');
const { doc, setDoc, updateDoc, deleteDoc, getDoc, getDocs, collection, writeBatch, Timestamp, serverTimestamp } = require('firebase/firestore');
let env;
const fixture = (extra = {}) => {
  const start = Timestamp.fromMillis(Date.now() + 86400000);
  return { title:'Akşam Maçı',venue:'Seçilen Saha',venueId:'google-place-id',venuePhotoUrl:'',
    latitude:40.5,longitude:30.5,price:250.5,maxPlayers:14,date:start,
    endDate:Timestamp.fromMillis(start.toMillis()+3600000),createdBy:'alice',creatorId:'alice',
    createdAt:serverTimestamp(),status:'open',currentPlayers:['alice'],positions:{'3':'alice'},
    teamA_name:'A Takımı',teamB_name:'B Takımı',...extra };
};
before(async () => {
  if (process.env.GCLOUD_PROJECT !== 'demo-depar-review' || process.env.FIRESTORE_EMULATOR_HOST !== '127.0.0.1:8088') throw new Error('Local demo only');
  env = await initializeTestEnvironment({ projectId:'demo-depar-metadata',firestore:{host:'127.0.0.1',port:8088,
    rules:readFileSync('../functions/rules/firestore.candidate.rules','utf8')} });
});
after(async () => { if (env) await env.cleanup(); });
const client = uid => env.authenticatedContext(uid).firestore();
beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async c => {
    const db = c.firestore();
    await setDoc(doc(db,'users/alice'),{profileVersion:2,fullName:'Alice',blockedUsers:[]});
    await setDoc(doc(db,'users/bob'),{profileVersion:2,fullName:'Bob',blockedUsers:[]});
    await setDoc(doc(db,'venues/catalog'),{name:'Trusted catalog',lat:40,lng:30});
    await setDoc(doc(db,'matches/game'),fixture());
  });
});

test('actual creation payload, manual location and legacy minimal service payload work', async () => {
  const db = client('alice');
  await assertSucceeds(setDoc(doc(db,'matches/new'),fixture()));
  await assertSucceeds(setDoc(doc(db,'matches/manual'),fixture({latitude:null,longitude:null,venueId:''})));
  await assertSucceeds(setDoc(doc(db,'matches/minimal'),{
    title:'Minimal',date:Timestamp.fromMillis(Date.now()+86400000),maxPlayers:10,
    createdBy:'alice',creatorId:'alice',createdAt:serverTimestamp(),status:'open',currentPlayers:['alice'],
  }));
});

test('invalid metadata cannot be created even by the authenticated owner', async () => {
  const bad = [{title:''},{title:'   '},{title:'x'.repeat(121)},{venue:'x'.repeat(201)},
    {teamA_name:'x'.repeat(61)},{teamB_name:12},{price:-1},{price:'250'},{price:NaN},{price:Infinity},
    {price:1000001},{latitude:91},{longitude:-181},{latitude:null,longitude:30},
    {latitude:'40'},{maxPlayers:13},{maxPlayers:14.5},{date:'tomorrow'},
    {endDate:Timestamp.fromMillis(0)},{endDate:null},{status:'admin'},
    {venueId:'other/path'},{venuePhotoUrl:'javascript:alert(1)'},{moderator:true},
    {createdAt:Timestamp.fromMillis(0)},{formation:'4-4-2'}];
  const ref = doc(client('alice'),'matches/invalid');
  for (const patch of bad) await assertFails(setDoc(ref,fixture(patch)));
});

test('owner metadata updates validate type, size, duration and future rescheduling', async () => {
  const ref = doc(client('alice'),'matches/game');
  await assertSucceeds(updateDoc(ref,{price:0,latitude:null,longitude:null,title:'Düzenlenen maç'}));
  for (const patch of [{price:-5},{venue:{name:'object'}},{endDate:'later'},
    {teamB_name:'x'.repeat(61)},{latitude:40},{adminNotes:'private'},
    {createdAt:serverTimestamp()},{status:'invalid'},
    {date:Timestamp.fromMillis(0),endDate:Timestamp.fromMillis(3600000)}]) {
    await assertFails(updateDoc(ref,patch));
  }
  const start = Timestamp.fromMillis(Date.now()+172800000);
  await assertSucceeds(updateDoc(ref,{date:start,endDate:Timestamp.fromMillis(start.toMillis()+1800000)}));
  await assertFails(updateDoc(ref,{endDate:Timestamp.fromMillis(start.toMillis()+1799999)}));
  await assertSucceeds(updateDoc(ref,{endDate:Timestamp.fromMillis(start.toMillis()+86400000)}));
  await assertFails(updateDoc(ref,{endDate:Timestamp.fromMillis(start.toMillis()+86400001)}));
});

test('formations must match the team size, including when changing capacity', async () => {
  const ref = doc(client('alice'),'matches/game');
  await assertSucceeds(updateDoc(ref,{formation:'2-3-1'}));
  await assertFails(updateDoc(ref,{formation:'4-4-2'}));
  await assertFails(updateDoc(ref,{maxPlayers:22}));
  await assertSucceeds(updateDoc(ref,{maxPlayers:22,formation:'4-4-2'}));
  const choices = {10:'1-2-1',12:'2-2-1',14:'2-3-1',16:'3-3-1',18:'3-4-1',20:'4-4-1',22:'4-4-2'};
  for (const [cap,formation] of Object.entries(choices)) {
    await assertSucceeds(setDoc(doc(client('alice'),`matches/size${cap}`),fixture({maxPlayers:Number(cap),formation})));
  }
});

test('dense 22-player format stays within rule budgets for edits, invitations and moves', async () => {
  const slots = [...Array.from({length:11},(_,i)=>`${i}`),...Array.from({length:11},(_,i)=>`opponent_${i}`)];
  const members = ['alice','bob',...Array.from({length:18},(_,i)=>`p${i}`)];
  const positions = Object.fromEntries(members.map((uid,i)=>[slots[i],uid]));
  await env.withSecurityRulesDisabled(async c => {
    const db = c.firestore();
    await setDoc(doc(db,'users/charlie'),{profileVersion:2,fullName:'Charlie',blockedUsers:[]});
    await setDoc(doc(db,'matches/game'),fixture({maxPlayers:22,currentPlayers:members,positions,formation:'4-4-2'}));
  });
  const owner = client('alice');
  await assertSucceeds(updateDoc(doc(owner,'matches/game'),{title:'Updated full format',price:500}));
  const invite = writeBatch(owner);
  invite.update(doc(owner,'matches/game'),{pendingPositions:{opponent_10:'charlie'},invitedPlayers:['charlie'],inviteSlot:'opponent_10'});
  invite.set(doc(owner,'notifications/dense'),{type:'match_invite',senderId:'alice',receiverId:'charlie',
    matchId:'game',positionId:'opponent_10',status:'pending',isRead:false,createdAt:serverTimestamp()});
  await assertSucceeds(invite.commit());
  delete positions['1']; positions.opponent_9='bob';
  await assertSucceeds(updateDoc(doc(client('bob'),'matches/game'),{positions,slotChange:{from:'1',to:'opponent_9',pending:''}}));
  const receiver = client('charlie');
  const accept = badRead => {
    const batch = writeBatch(receiver);
    batch.update(doc(receiver,'matches/game'),{currentPlayers:[...members,'charlie'],positions:{...positions,opponent_10:'charlie'},
      pendingPositions:{},invitedPlayers:[],slotChange:{from:'',to:'opponent_10',pending:'opponent_10'}});
    batch.update(doc(receiver,'notifications/dense'),{status:'accepted',isRead:badRead});
    return batch;
  };
  await assertFails(accept('invalid').commit());
  await assertSucceeds(accept(true).commit());
});

test('shared venue catalog is authenticated read-only, even for creator or moderator claims', async () => {
  await assertFails(getDoc(doc(env.unauthenticatedContext().firestore(),'venues/catalog')));
  const db = client('alice');
  assert.equal((await assertSucceeds(getDocs(collection(db,'venues')))).size,1);
  for (const actor of [db,env.authenticatedContext('mod',{moderator:true}).firestore()]) {
    await assertFails(setDoc(doc(actor,'venues/new'),{name:'Forged',createdBy:'alice',source:'google'}));
    await assertFails(updateDoc(doc(actor,'venues/catalog'),{name:'Overwritten'}));
    await assertFails(deleteDoc(doc(actor,'venues/catalog')));
  }
});

test('complete rules deny unknown paths, private internals and writes under deletion barrier', async () => {
  const db = client('alice');
  for (const path of ['unknown/doc','matches/game/private/data','venues/catalog/private/data',
    '_loginLimits/test','accountDeletionJobs/alice','contentReports/report','_safetyLocks/test']) {
    await assertFails(setDoc(doc(db,path),{value:true}));
    await assertFails(getDoc(doc(db,path)));
  }
  await env.withSecurityRulesDisabled(c => setDoc(doc(c.firestore(),'accountDeletionJobs/alice'),{status:'pending'}));
  await assertFails(setDoc(doc(db,'matches/new'),fixture()));
  await assertFails(updateDoc(doc(db,'matches/game'),{title:'blocked'}));
  await assertFails(deleteDoc(doc(db,'matches/game')));
  await assertSucceeds(getDoc(doc(db,'matches/game')));
});

test('complete rules preserve request and paired friendship acceptance', async () => {
  const sender = client('alice');
  await assertSucceeds(setDoc(doc(sender,'users/bob/followRequests/alice'),{from:'alice',status:'pending',createdAt:serverTimestamp()}));
  const receiver = client('bob'), batch = writeBatch(receiver);
  for (const [a,b,name] of [['bob','alice','Alice'],['alice','bob','Bob']]) {
    batch.set(doc(receiver,`users/${a}/friends/${b}`),{uid:b,fullName:name,avatarUrl:'',avatarData:'0',position:'',since:serverTimestamp()});
  }
  batch.delete(doc(receiver,'users/bob/followRequests/alice'));
  await assertSucceeds(batch.commit());
});
