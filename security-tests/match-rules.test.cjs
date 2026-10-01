const { before, after, beforeEach, test } = require('node:test');
const assert = require('node:assert/strict');
const { readFileSync } = require('node:fs');
const { assembleRules } = require('../functions/rules/assemble.cjs');
const { initializeTestEnvironment, assertSucceeds, assertFails } = require('@firebase/rules-unit-testing');
const { doc, setDoc, getDoc, updateDoc, writeBatch, runTransaction, Timestamp, serverTimestamp } = require('firebase/firestore');
let env;
const fixture = (extra = {}) => ({ createdBy: 'alice', creatorId: 'alice', title: 'Test', status: 'open',
  date: Timestamp.fromMillis(Date.now() + 86400000), maxPlayers: 10, currentPlayers: ['alice'],
  positions: { '0': 'alice' }, pendingPositions: {}, invitedPlayers: [], createdAt:serverTimestamp(), ...extra });
before(async () => {
  if (process.env.GCLOUD_PROJECT !== 'demo-depar-review' || process.env.FIRESTORE_EMULATOR_HOST !== '127.0.0.1:8088') throw new Error('Local demo only');
  const rules = readFileSync('../functions/rules/firestore.candidate.rules', 'utf8');
  assert.equal(rules, assembleRules(), 'Regenerate candidate rules before testing');
  env = await initializeTestEnvironment({ projectId: 'demo-depar-match', firestore: { host: '127.0.0.1', port: 8088,
    rules,
  } });
});
after(async () => { if (env) await env.cleanup(); });
async function seed(data) { await env.withSecurityRulesDisabled(async c => {
  const db = c.firestore(); for (const [path, value] of Object.entries(data)) {
    await setDoc(doc(db, path), /^users\/[^/]+$/.test(path) ? {profileVersion:2, ...value} : value);
  }
}); }
beforeEach(async () => {
  await env.clearFirestore();
  await seed({ 'users/alice': { blockedUsers: [] }, 'users/bob': { blockedUsers: [] },
    'users/charlie': { blockedUsers: [] }, 'matches/game': fixture() });
});
const client = uid => env.authenticatedContext(uid).firestore();
const match = uid => doc(client(uid), 'matches/game');
test('owner metadata edit succeeds, outsider edit and owner transfer fail', async () => {
  await assertSucceeds(updateDoc(match('alice'), { title: 'Updated' }));
  for (const patch of [{ title: 'Forged' }, { maxPlayers: 22 }, { date: Timestamp.now() }, { createdBy: 'bob', creatorId: 'bob' }]) {
    await assertFails(updateDoc(match('bob'), patch));
  }
  await assertFails(updateDoc(match('alice'), { creatorId: 'bob' }));
});
test('only self can join; duplicate members, overflow and forcing another player fail', async () => {
  await assertSucceeds(updateDoc(match('bob'), { currentPlayers: ['alice', 'bob'] }));
  await assertFails(updateDoc(match('charlie'), { currentPlayers: ['alice', 'bob', 'bob'] }));
  await assertFails(updateDoc(match('charlie'), { currentPlayers: ['alice', 'bob', 'someone'] }));
  await assertFails(updateDoc(match('alice'), { currentPlayers: ['alice', 'bob', 'charlie'] }));
  await seed({ 'matches/game': fixture({ currentPlayers: ['alice', ...Array.from({ length: 9 }, (_, i) => `p${i}`)] }) });
  await assertFails(updateDoc(match('bob'), { currentPlayers: ['alice', ...Array.from({ length: 9 }, (_, i) => `p${i}`), 'bob'] }));
});
test('player may move only self; occupied, duplicate, invalid and reserved slots fail', async () => {
  await seed({ 'matches/game': fixture({ currentPlayers: ['alice','bob'], positions: { '0':'alice', '1':'bob' }, pendingPositions: { '2':'charlie' }, invitedPlayers:['charlie'] }) });
  await assertSucceeds(updateDoc(match('bob'), { positions: { '0':'alice', '3':'bob' }, slotChange:{from:'1',to:'3',pending:''} }));
  for (const positions of [{ '0':'bob' }, { '0':'alice', '1':'bob', '3':'bob' }, { '0':'alice', '5':'bob' }, { '0':'alice', '2':'bob' }, { '0':'charlie', '3':'bob' }]) {
    await assertFails(updateDoc(match('bob'), { positions }));
  }
  await assertFails(updateDoc(match('charlie'), { positions: { '0':'alice', '3':'bob', '4':'charlie' } }));
});
test('concurrent transactions on one free position leave exactly one winner', async () => {
  await seed({ 'matches/game': fixture({ currentPlayers: ['alice','bob','charlie'] }) });
  const results = await Promise.allSettled(['bob','charlie'].map(uid => {
    const db = client(uid), ref = doc(db, 'matches/game');
    return runTransaction(db, async tx => {
      const m = (await tx.get(ref)).data();
      if (m.positions['1']) throw new Error('occupied');
      tx.update(ref, { positions: { ...m.positions, '1': uid }, slotChange:{from:'',to:'1',pending:''} });
    });
  }));
  assert.equal(results.filter(r => r.status === 'fulfilled').length, 1);
  assert.ok(['bob','charlie'].includes((await getDoc(match('alice'))).data().positions['1']));
});
test('concurrent last-place joins cannot exceed capacity', async () => {
  await seed({ 'matches/game': fixture({ currentPlayers: ['alice', ...Array.from({ length:8 }, (_,i) => `p${i}`)] }) });
  const results = await Promise.allSettled(['bob','charlie'].map(uid => {
    const db = client(uid), ref = doc(db, 'matches/game');
    return runTransaction(db, async tx => {
      const m = (await tx.get(ref)).data();
      if (m.currentPlayers.length >= m.maxPlayers) throw new Error('full');
      tx.update(ref, { currentPlayers: [...m.currentPlayers, uid] });
    });
  }));
  assert.equal(results.filter(r => r.status === 'fulfilled').length, 1);
  assert.equal((await getDoc(match('alice'))).data().currentPlayers.length, 10);
});
test('leaving requires slot cleanup, may proceed after block; cannot remove someone else or owner', async () => {
  await seed({ 'matches/game': fixture({ currentPlayers:['alice','bob'], positions:{ '0':'alice','1':'bob' } }),
    'users/alice': { blockedUsers:['bob'] } });
  await assertFails(updateDoc(match('bob'), { currentPlayers:['alice'] }));
  await assertSucceeds(updateDoc(match('bob'), { currentPlayers:['alice'], positions:{ '0':'alice' }, slotChange:{from:'1',to:'',pending:''} }));
  await assertFails(updateDoc(match('charlie'), { currentPlayers:[], positions:{} }));
  await assertFails(updateDoc(match('alice'), { currentPlayers:[], positions:{} }));
});
test('only captain can kick another player and must clean their slot', async () => {
  await seed({ 'matches/game': fixture({ currentPlayers:['alice','bob','charlie'], positions:{ '0':'alice','1':'bob' } }) });
  const patch = { currentPlayers:['alice','charlie'], positions:{ '0':'alice' } };
  await assertFails(updateDoc(match('charlie'), patch));
  await assertSucceeds(updateDoc(match('alice'), patch));
});
test('real reserved invitation acceptance is atomic and only for recipient', async () => {
  const db=client('alice'), batch=writeBatch(db);
  batch.update(doc(db,'matches/game'), { pendingPositions:{ '1':'bob' }, invitedPlayers:['bob'], inviteSlot:'1' });
  batch.set(doc(db,'notifications/invite'), { type:'match_invite', senderId:'alice', receiverId:'bob',
    matchId:'game', positionId:'1', status:'pending', isRead:false, createdAt:serverTimestamp() });
  await assertSucceeds(batch.commit());
  await assertFails(updateDoc(doc(client('charlie'),'notifications/invite'), { status:'accepted' }));
  await assertFails(updateDoc(doc(client('bob'),'notifications/invite'), { status:'accepted' }));
  const receiver=client('bob'), accept=writeBatch(receiver);
  accept.update(doc(receiver,'matches/game'), { currentPlayers:['alice','bob'], positions:{ '0':'alice','1':'bob' }, pendingPositions:{}, invitedPlayers:[], slotChange:{from:'',to:'1',pending:'1'} });
  accept.update(doc(receiver,'notifications/invite'), { status:'accepted', isRead:true });
  await assertSucceeds(accept.commit());
});
test('blocked, closed and past matches reject join; deleting accounts cannot write', async () => {
  await seed({ 'users/alice': { blockedUsers:['bob'] } });
  await assertFails(updateDoc(match('bob'), { currentPlayers:['alice','bob'] }));
  await seed({ 'users/alice': { blockedUsers:[] }, 'matches/game':fixture({ status:'closed' }) });
  await assertFails(updateDoc(match('bob'), { currentPlayers:['alice','bob'] }));
  await seed({ 'matches/game':fixture({ date:Timestamp.fromMillis(0) }) });
  await assertFails(updateDoc(match('bob'), { currentPlayers:['alice','bob'] }));
  await seed({ 'matches/game':fixture(), 'accountDeletionJobs/bob':{ status:'pending' } });
  await assertFails(updateDoc(match('bob'), { currentPlayers:['alice','bob'] }));
});
test('22-player boundary permits opponent_10 but denies malformed or overflowing slots', async () => {
  await seed({ 'matches/game':fixture({ maxPlayers:22, currentPlayers:['alice','bob'] }) });
  await assertSucceeds(updateDoc(match('bob'), { positions:{ '0':'alice', 'opponent_10':'bob' }, slotChange:{from:'',to:'opponent_10',pending:''} }));
  await assertFails(updateDoc(match('bob'), { positions:{ '0':'alice', 'opponent_11':'bob' } }));
  await assertFails(updateDoc(match('bob'), { positions:{ '0':'alice', '01':'bob' } }));
});
test('forged change descriptors cannot evict another player or clear their reservation', async () => {
  await seed({ 'matches/game':fixture({currentPlayers:['alice','bob'], positions:{'0':'alice','1':'bob'}, pendingPositions:{'2':'charlie'}, invitedPlayers:['charlie']}) });
  await assertFails(updateDoc(match('bob'), { positions:{'0':'bob'}, slotChange:{from:'1',to:'0',pending:''} }));
  await assertFails(updateDoc(match('bob'), { positions:{'1':'bob'}, slotChange:{from:'0',to:'',pending:''} }));
  await assertFails(updateDoc(match('bob'), { pendingPositions:{}, invitedPlayers:[], slotChange:{from:'',to:'',pending:'2'} }));
  await assertFails(updateDoc(match('bob'), { slotChange:{uid:'alice',payload:'unexpected'} }));
});
test('blocked invite can be declined and owner cannot invite into occupied slot', async () => {
  await seed({ 'matches/game':fixture({pendingPositions:{'1':'bob'},invitedPlayers:['bob']}), 'users/alice':{blockedUsers:['bob']} });
  await assertSucceeds(updateDoc(match('bob'), {pendingPositions:{},invitedPlayers:[],slotChange:{from:'',to:'',pending:'1'}}));
  await assertFails(updateDoc(match('alice'), {pendingPositions:{'0':'charlie'},invitedPlayers:['charlie'],inviteSlot:'0'}));
});
test('new match and private own success notification preserve existing create flow', async () => {
  const db=client('alice');
  await assertSucceeds(setDoc(doc(db,'matches/new'), fixture()));
  const notice={ title:'Maç oluşturuldu', message:'Test', isRead:false, createdAt:serverTimestamp() };
  await assertSucceeds(setDoc(doc(db,'users/alice/notifications/own'),notice));
  await assertFails(setDoc(doc(client('bob'),'users/alice/notifications/forged'),notice));
  await assertFails(setDoc(doc(client('bob'),'matches/forged'),fixture()));
});
test('closed match forbids owner moves and new invitations but permits cleanup', async () => {
  await seed({ 'matches/game':fixture({status:'closed',currentPlayers:['alice','bob'],positions:{'0':'alice','1':'bob'}}) });
  await assertFails(updateDoc(match('alice'), {positions:{'2':'alice','1':'bob'}}));
  await assertFails(updateDoc(match('alice'), {pendingPositions:{'3':'charlie'},invitedPlayers:['charlie'],inviteSlot:'3'}));
  await assertSucceeds(updateDoc(match('alice'), {currentPlayers:['alice'],positions:{'0':'alice'}}));
});
