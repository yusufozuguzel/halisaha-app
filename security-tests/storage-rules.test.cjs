const {before,beforeEach,after,test} = require('node:test');
const assert = require('node:assert/strict');
const {readFileSync} = require('node:fs');
const {initializeTestEnvironment,assertSucceeds,assertFails} = require('@firebase/rules-unit-testing');
const {ref,uploadBytes,deleteObject,getMetadata,updateMetadata,listAll,getDownloadURL} = require('firebase/storage');
const {doc,setDoc,deleteDoc} = require('firebase/firestore');
const {assembleStorageRules} = require('../functions/rules/assemble.cjs');
let env;
const bytes = new Uint8Array([0xff,0xd8,0xff,1]);
const image = {contentType:'image/jpeg'};
const file = (uid, path = `profile_images/${uid}.jpg`) => ref(env.authenticatedContext(uid).storage(),path);
const seed = (path,data) => env.withSecurityRulesDisabled(c=>setDoc(doc(c.firestore(),path),data));
before(async()=>{
  if(process.env.GCLOUD_PROJECT!=='demo-depar-review'||process.env.FIRESTORE_EMULATOR_HOST!=='127.0.0.1:8088'
    ||process.env.FIREBASE_STORAGE_EMULATOR_HOST!=='127.0.0.1:9198')throw new Error('Local demo only');
  const rules=readFileSync('../functions/rules/storage.candidate.rules','utf8');
  assert.equal(rules,assembleStorageRules());
  env=await initializeTestEnvironment({projectId:'demo-depar-review',firestore:{host:'127.0.0.1',port:8088},
    storage:{host:'127.0.0.1',port:9198,rules}});
});
beforeEach(async()=>{await env.clearFirestore();await env.clearStorage();});
after(async()=>{if(env)await env.cleanup();});

test('owner can upload/replace/delete; signed-in peers can read profile photos but cannot change them',async()=>{
  await assertSucceeds(uploadBytes(file('alice'),bytes,image));
  await assertSucceeds(uploadBytes(file('alice'),bytes,{contentType:'image/png'}));
  await assertSucceeds(getDownloadURL(file('alice')));
  await assertSucceeds(getMetadata(file('bob','profile_images/alice.jpg')));
  await assertFails(uploadBytes(file('bob','profile_images/alice.jpg'),bytes,image));
  await assertFails(updateMetadata(file('bob','profile_images/alice.jpg'),{contentType:'image/webp'}));
  await assertFails(deleteObject(file('bob','profile_images/alice.jpg')));
  await assertSucceeds(deleteObject(file('alice')));
});

test('anonymous SDK access, object listing, nested paths and unsupported paths are denied',async()=>{
  await assertSucceeds(uploadBytes(file('alice'),bytes,image));
  const anon=ref(env.unauthenticatedContext().storage(),'profile_images/alice.jpg');
  await assertFails(getMetadata(anon));
  await assertFails(uploadBytes(anon,bytes,image));
  await assertFails(deleteObject(anon));
  await assertFails(listAll(ref(env.authenticatedContext('alice').storage(),'profile_images')));
  for(const path of ['private/alice.jpg','profile_images/alice/photo.jpg','profile_images/alice.png','profile_images/alice.jpg.exe']){
    await assertFails(uploadBytes(file('alice',path),bytes,image));
  }
  await env.withSecurityRulesDisabled(c=>uploadBytes(ref(c.storage(),'private/existing.txt'),bytes));
  await assertFails(getMetadata(file('alice','private/existing.txt')));
});

test('size boundaries and declared MIME are enforced on uploads and metadata changes',async()=>{
  for(const contentType of ['image/jpeg','image/png','image/webp']){
    await assertSucceeds(uploadBytes(file('alice'),bytes,{contentType}));
  }
  for(const contentType of ['text/html','image/svg+xml','application/octet-stream','image/gif']){
    await assertFails(uploadBytes(file('alice'),bytes,{contentType}));
    await assertFails(updateMetadata(file('alice'),{contentType}));
  }
  await assertFails(uploadBytes(file('alice'),bytes));
  await assertFails(uploadBytes(file('alice'),new Uint8Array(),image));
  await assertSucceeds(uploadBytes(file('alice'),new Uint8Array(5*1024*1024),image));
  await assertFails(uploadBytes(file('alice'),new Uint8Array(5*1024*1024+1),image));
});

test('deletion tombstones reject new upload, overwrite, metadata changes and deletion with existing tokens',async()=>{
  await uploadBytes(file('alice'),bytes,image);
  for(const status of ['pending','processing','completed']){
    await seed('accountDeletionJobs/alice',{status});
    await assertFails(uploadBytes(file('alice'),bytes,image));
    await assertFails(updateMetadata(file('alice'),{cacheControl:'public'}));
    await assertFails(deleteObject(file('alice')));
    await assertSucceeds(uploadBytes(file('bob'),bytes,image));
  }
  await seed('accountDeletionJobs/new',{status:'pending'});
  await assertFails(uploadBytes(file('new'),bytes,image));
});

test('restriction blocks writes and restoration allows the same account to upload again',async()=>{
  await uploadBytes(file('alice'),bytes,image);
  await seed('_moderationAccounts/alice',{reportId:'test'});
  await assertFails(uploadBytes(file('alice'),bytes,image));
  await assertFails(updateMetadata(file('alice'),{contentType:'image/png'}));
  await assertFails(deleteObject(file('alice')));
  await assertSucceeds(uploadBytes(file('bob'),bytes,image));
  await env.withSecurityRulesDisabled(c=>deleteDoc(doc(c.firestore(),'_moderationAccounts/alice')));
  await assertSucceeds(uploadBytes(file('alice'),bytes,image));
});

test('fake ownership metadata/claims cannot grant access; owners can remove legacy invalid files',async()=>{
  await assertFails(uploadBytes(file('bob','profile_images/alice.jpg'),bytes,{...image,customMetadata:{owner:'bob',uid:'bob'}}));
  await assertFails(uploadBytes(ref(env.authenticatedContext('mod',{moderator:true}).storage(),'profile_images/alice.jpg'),bytes,image));
  await env.withSecurityRulesDisabled(c=>uploadBytes(ref(c.storage(),'profile_images/alice.jpg'),bytes,{contentType:'text/plain'}));
  await assertSucceeds(deleteObject(file('alice')));
});
