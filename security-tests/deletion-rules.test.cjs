const {before,after,beforeEach,test} = require('node:test');
const {readFileSync} = require('node:fs');
const {initializeTestEnvironment,assertSucceeds,assertFails} = require('@firebase/rules-unit-testing');
const {doc,setDoc,updateDoc,deleteDoc,getDoc,writeBatch,Timestamp,serverTimestamp,arrayUnion} = require('firebase/firestore');
let env;
before(async()=>{
  if(process.env.GCLOUD_PROJECT!=='demo-depar-review'||process.env.FIRESTORE_EMULATOR_HOST!=='127.0.0.1:8088') throw new Error('Local demo only');
  env=await initializeTestEnvironment({projectId:'demo-depar-deletion-rules',firestore:{host:'127.0.0.1',port:8088,
    rules:readFileSync('../functions/rules/firestore.candidate.rules','utf8')}});
});
after(async()=>{if(env)await env.cleanup();});
const client=uid=>env.authenticatedContext(uid).firestore();
const game=owner=>({createdBy:owner,creatorId:owner,title:'Match',maxPlayers:10,status:'open',
  date:Timestamp.fromMillis(Date.now()+86400000),currentPlayers:[owner],createdAt:serverTimestamp()});
async function seed(data){await env.withSecurityRulesDisabled(async c=>{
  const db=c.firestore();for(const [path,value]of Object.entries(data))await setDoc(doc(db,path),value);
});}
beforeEach(async()=>{
  await env.clearFirestore();
  await seed({'users/alice':{profileVersion:2,fullName:'Alice',blockedUsers:[]},
    'users/bob':{profileVersion:2,fullName:'Bob',blockedUsers:[]},
    'users/carol':{profileVersion:2,fullName:'Carol',blockedUsers:[]},
    'matches/owned':game('alice'),'matches/other':game('bob'),
    'accountDeletionJobs/alice':{status:'processing'}});
});

test('deleting account cannot write; other profiles, matches and invitations still work',async()=>{
  const alice=client('alice'),bob=client('bob');
  await assertFails(updateDoc(doc(alice,'users/alice'),{fullName:'Changed'}));
  await assertFails(setDoc(doc(alice,'matches/new'),game('alice')));
  await assertFails(deleteDoc(doc(alice,'matches/owned')));
  await assertFails(setDoc(doc(alice,'users/bob/followRequests/alice'),{from:'alice',status:'pending',createdAt:serverTimestamp()}));
  await assertSucceeds(updateDoc(doc(bob,'users/bob'),{fullName:'Still active'}));
  await assertSucceeds(setDoc(doc(bob,'matches/new'),game('bob')));
  await assertSucceeds(updateDoc(doc(bob,'matches/other'),{price:100}));
  await assertSucceeds(setDoc(doc(bob,'users/carol/followRequests/bob'),{from:'bob',status:'pending',createdAt:serverTimestamp()}));
  await assertSucceeds(getDoc(doc(bob,'matches/owned'))); // Only writes freeze.
});

test('new inbound references to deleting account and its matches are denied',async()=>{
  const bob=client('bob');
  await assertFails(setDoc(doc(bob,'users/alice/followRequests/bob'),{from:'bob',status:'pending',createdAt:serverTimestamp()}));
  await assertFails(updateDoc(doc(bob,'users/bob'),{blockedUsers:arrayUnion('alice')}));
  await assertFails(updateDoc(doc(bob,'matches/owned'),{currentPlayers:['alice','bob']}));
  const invite=writeBatch(bob);
  invite.update(doc(bob,'matches/other'),{pendingPositions:{1:'alice'},invitedPlayers:['alice'],inviteSlot:'1'});
  invite.set(doc(bob,'notifications/invite'),{senderId:'bob',receiverId:'alice',matchId:'other',positionId:'1',
    type:'match_invite',status:'pending',isRead:false,createdAt:serverTimestamp()});
  await assertFails(invite.commit());
  await assertFails(updateDoc(doc(bob,'matches/other'),{currentPlayers:['bob','alice']}));
});

test('block list allows active single additions and removals but rejects forged bulk references',async()=>{
  const bob=client('bob');
  await assertSucceeds(updateDoc(doc(bob,'users/bob'),{blockedUsers:['carol']}));
  await assertFails(updateDoc(doc(bob,'users/bob'),{blockedUsers:['carol','alice']}));
  await assertFails(updateDoc(doc(bob,'users/bob'),{blockedUsers:['carol','carol']}));
  await assertFails(updateDoc(doc(bob,'users/bob'),{blockedUsers:['carol',{uid:'alice'}]}));
  await assertFails(setDoc(doc(client('new'),'users/new'),{profileVersion:2,blockedUsers:['alice']}));
  await seed({'users/bob':{profileVersion:2,blockedUsers:['alice','carol']}});
  await assertSucceeds(updateDoc(doc(bob,'users/bob'),{blockedUsers:['carol']}));
  await assertSucceeds(updateDoc(doc(bob,'users/bob'),{blockedUsers:[]}));
});

test('cleanup removal is permitted; removed membership cannot be restored by an old roster',async()=>{
  await seed({'matches/other':{...game('bob'),currentPlayers:['bob','alice'],positions:{0:'bob',1:'alice'}}});
  const bob=client('bob');
  await assertSucceeds(updateDoc(doc(bob,'matches/other'),{currentPlayers:['bob'],positions:{0:'bob'}}));
  await assertFails(updateDoc(doc(bob,'matches/other'),{currentPlayers:['bob','alice'],positions:{0:'bob',1:'alice'}}));
  await assertSucceeds(deleteDoc(doc(bob,'users/bob/friends/alice')));
  await assertSucceeds(deleteDoc(doc(bob,'users/alice/friends/bob')));
});

test('completed account tombstone still rejects stale tokens and retired match IDs cannot be reused',async()=>{
  await seed({'accountDeletionJobs/alice':{status:'completed'},'_retiredMatches/old':{retiredAt:Timestamp.now()}});
  await assertFails(setDoc(doc(client('alice'),'users/alice'),{profileVersion:2,name:'Recreated'}));
  await assertFails(setDoc(doc(client('bob'),'matches/old'),game('bob')));
  await assertFails(deleteDoc(doc(client('bob'),'_retiredMatches/old')));
  await assertSucceeds(setDoc(doc(client('bob'),'matches/fresh'),game('bob')));
});
