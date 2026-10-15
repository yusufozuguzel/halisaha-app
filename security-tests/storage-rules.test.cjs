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
const seedPhoto = (path='profile_images/alice.jpg', metadata=image) =>
  env.withSecurityRulesDisabled(c=>uploadBytes(ref(c.storage(),path),bytes,metadata));
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

test('owners cannot bypass server scanning; authenticated reading and guarded owner deletion remain',async()=>{
  await assertFails(uploadBytes(file('alice'),bytes,image));
  await seedPhoto();
  await assertFails(uploadBytes(file('alice'),bytes,{contentType:'image/png'}));
  await assertFails(updateMetadata(file('alice'),{contentType:'image/webp'}));
  await assertSucceeds(getDownloadURL(file('alice')));
  await assertSucceeds(getMetadata(file('bob','profile_images/alice.jpg')));
  await assertFails(uploadBytes(file('bob','profile_images/alice.jpg'),bytes,image));
  await assertFails(updateMetadata(file('bob','profile_images/alice.jpg'),{contentType:'image/webp'}));
  await assertFails(deleteObject(file('bob','profile_images/alice.jpg')));
  await assertSucceeds(deleteObject(file('alice')));
});

test('anonymous SDK access, object listing, nested paths and unsupported paths are denied',async()=>{
  await seedPhoto();
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

test('valid MIME, small images, download tokens and approval metadata cannot bypass server scanning',async()=>{
  for(const contentType of ['image/jpeg','image/png','image/webp']){
    await assertFails(uploadBytes(file('alice'),bytes,{contentType}));
  }
  await seedPhoto();
  for(const contentType of ['text/html','image/svg+xml','application/octet-stream','image/gif']){
    await assertFails(uploadBytes(file('alice'),bytes,{contentType}));
    await assertFails(updateMetadata(file('alice'),{contentType}));
  }
  await assertFails(uploadBytes(file('alice'),bytes));
  await assertFails(uploadBytes(file('alice'),new Uint8Array(),image));
  await assertFails(uploadBytes(file('alice'),new Uint8Array(5*1024*1024),image));
  await assertFails(uploadBytes(file('alice'),new Uint8Array(5*1024*1024+1),image));
  for(const customMetadata of [{firebaseStorageDownloadTokens:'attacker-token'},
    {owner:'alice',uid:'alice',moderationApproved:'true'}]){
    await assertFails(uploadBytes(file('alice'),bytes,{...image,customMetadata}));
    await assertFails(updateMetadata(file('alice'),{customMetadata}));
  }
});

test('deletion tombstones reject new upload, overwrite, metadata changes and deletion with existing tokens',async()=>{
  await seedPhoto();
  for(const status of ['pending','processing','completed']){
    await seed('accountDeletionJobs/alice',{status});
    await assertFails(uploadBytes(file('alice'),bytes,image));
    await assertFails(updateMetadata(file('alice'),{cacheControl:'public'}));
    await assertFails(deleteObject(file('alice')));
    await seedPhoto('profile_images/bob.jpg');
    await assertSucceeds(deleteObject(file('bob')));
  }
  await seed('accountDeletionJobs/new',{status:'pending'});
  await assertFails(uploadBytes(file('new'),bytes,image));
});

test('restriction blocks owner deletion and restoration permits deletion without permitting unscanned upload',async()=>{
  await seedPhoto();
  await seed('_moderationAccounts/alice',{reportId:'test'});
  await assertFails(uploadBytes(file('alice'),bytes,image));
  await assertFails(updateMetadata(file('alice'),{contentType:'image/png'}));
  await assertFails(deleteObject(file('alice')));
  await seedPhoto('profile_images/bob.jpg');
  await assertSucceeds(deleteObject(file('bob')));
  await env.withSecurityRulesDisabled(c=>deleteDoc(doc(c.firestore(),'_moderationAccounts/alice')));
  await assertSucceeds(deleteObject(file('alice')));
  await assertFails(uploadBytes(file('alice'),bytes,image));
});

test('fake ownership metadata/claims cannot grant access; owners can remove legacy invalid files',async()=>{
  await assertFails(uploadBytes(file('bob','profile_images/alice.jpg'),bytes,{...image,customMetadata:{owner:'bob',uid:'bob'}}));
  await assertFails(uploadBytes(ref(env.authenticatedContext('mod',{moderator:true}).storage(),'profile_images/alice.jpg'),bytes,image));
  await env.withSecurityRulesDisabled(c=>uploadBytes(ref(c.storage(),'profile_images/alice.jpg'),bytes,{contentType:'text/plain'}));
  await assertSucceeds(deleteObject(file('alice')));
});
