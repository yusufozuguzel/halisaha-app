const {test,before,after} = require('node:test');
const {readFileSync} = require('node:fs');
const {initializeTestEnvironment,assertSucceeds,assertFails} = require('@firebase/rules-unit-testing');
const {ref,uploadBytes,deleteObject,getMetadata} = require('firebase/storage');
let env;
before(async()=>{
  if(process.env.GCLOUD_PROJECT!=='demo-depar-review'||process.env.FIREBASE_STORAGE_EMULATOR_HOST!=='127.0.0.1:9198')throw new Error('Local demo only');
  env=await initializeTestEnvironment({projectId:'demo-depar-review',storage:{host:'127.0.0.1',port:9198,
    rules:readFileSync('fixtures/user-provided.storage.rules','utf8')}});
  await env.clearStorage();
});
after(async()=>{if(env)await env.cleanup();});
test('UNSAFE BASELINE: signed-in stranger can read, replace and delete another account file',async()=>{
  const path='private/alice.txt';
  await uploadBytes(ref(env.authenticatedContext('alice').storage(),path),new Uint8Array([1]));
  const stranger=ref(env.authenticatedContext('bob').storage(),path);
  await assertSucceeds(getMetadata(stranger));
  await assertSucceeds(uploadBytes(stranger,new Uint8Array([2]),{contentType:'text/html'}));
  await assertSucceeds(deleteObject(stranger));
  await assertFails(uploadBytes(ref(env.unauthenticatedContext().storage(),path),new Uint8Array([3])));
});
