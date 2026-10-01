const {before,after,test} = require('node:test');
const {readFileSync} = require('node:fs');
const {initializeTestEnvironment,assertSucceeds,assertFails} = require('@firebase/rules-unit-testing');
const {doc,setDoc} = require('firebase/firestore');
const {ref,uploadBytes,deleteObject} = require('firebase/storage');
let env;
before(async()=>{
  if(process.env.GCLOUD_PROJECT!=='demo-depar-review'||process.env.FIRESTORE_EMULATOR_HOST!=='127.0.0.1:8088'
    ||process.env.FIREBASE_STORAGE_EMULATOR_HOST!=='127.0.0.1:9198')throw new Error('Local demo only');
  const helper=readFileSync('../functions/rules/storage.fragment.rules','utf8');
  // Cross-service Storage lookups use the emulator's configured project.
  env=await initializeTestEnvironment({projectId:'demo-depar-review',
    firestore:{host:'127.0.0.1',port:8088},storage:{host:'127.0.0.1',port:9198,
      // Minimal OWNER-ONLY fixture, not the unknown production Storage rules.
      rules:`rules_version = '2'; service firebase.storage { match /b/{bucket}/o {
        ${helper}
        match /profile_images/{fileName} { allow write: if safetyWritesAllowed() && fileName == request.auth.uid + '.jpg'; }
      } }`}});
  await env.clearFirestore();
});
after(async()=>{if(env)await env.cleanup();});
test('Storage guard freezes only deleting owner, including stale-token overwrite/delete',async()=>{
  const alice=env.authenticatedContext('alice').storage();
  const bob=env.authenticatedContext('bob').storage();
  const bytes=new Uint8Array([1,2,3]);
  await assertSucceeds(uploadBytes(ref(alice,'profile_images/alice.jpg'),bytes));
  await env.withSecurityRulesDisabled(c=>setDoc(doc(c.firestore(),'accountDeletionJobs/alice'),{status:'processing'}));
  await assertFails(uploadBytes(ref(alice,'profile_images/alice.jpg'),bytes));
  await assertFails(deleteObject(ref(alice,'profile_images/alice.jpg')));
  await assertFails(uploadBytes(ref(bob,'profile_images/alice.jpg'),bytes));
  await assertSucceeds(uploadBytes(ref(bob,'profile_images/bob.jpg'),bytes));
  await assertSucceeds(deleteObject(ref(bob,'profile_images/bob.jpg')));
  await env.withSecurityRulesDisabled(c=>setDoc(doc(c.firestore(),'accountDeletionJobs/alice'),{status:'completed'}));
  await assertFails(uploadBytes(ref(alice,'profile_images/alice.jpg'),bytes));
});

test('Storage blocks restricted account writes without blocking unrelated accounts',async()=>{
  await env.withSecurityRulesDisabled(c=>setDoc(doc(c.firestore(),'_moderationAccounts/restricted'),{reportId:'test'}));
  const bytes=new Uint8Array([1,2,3]);
  await assertFails(uploadBytes(ref(env.authenticatedContext('restricted').storage(),'profile_images/restricted.jpg'),bytes));
  await assertSucceeds(uploadBytes(ref(env.authenticatedContext('active').storage(),'profile_images/active.jpg'),bytes));
});
