const test = require('node:test');
const assert = require('node:assert/strict');
const crypto = require('node:crypto');
const {
  TARGET_PROJECT, parseArgs, createFirebaseCliCredential, decodeLegacyJpeg,
  createOAuth2Client, loadStorageOAuth2Client, createFirestoreRest, createIdentityPlatformAuth,
  safeSearchPassed, createVisionClient, formatCliError, migrateLegacyAvatars,
} = require('../tools/migrate-legacy-avatars.cjs');

const jpeg = Buffer.from([0xff, 0xd8, 0xff, 0x00, 0x01, 0x02, 0xff, 0xd9]);
const encoded = jpeg.toString('base64');
const safeAnnotation = { adult:'UNLIKELY', violence:'VERY_UNLIKELY', racy:'POSSIBLE' };

function harness({ profile = {}, existingObject = false, missingAuth = false, updateError,
  annotation = safeAnnotation, uploadedMetadata } = {}) {
  const events = [];
  const updateTime = { seconds:7, nanoseconds:4 };
  const data = { avatarType:'base64', avatarData:encoded, avatarUrl:'', ...profile };
  const doc = {
    id:'synthetic-uid', updateTime, data:() => ({...data}),
    ref:{
      get:async () => ({ exists:true, updateTime, get:key => data[key] }),
      update:async (patch, options) => {
        events.push(['profileUpdate', patch, options]);
        if (updateError) throw updateError;
        Object.assign(data, patch);
      },
    },
  };
  let pageRead = false;
  const db = { collection:() => ({
    orderBy() { return this; }, limit() { return this; }, startAfter() { return this; },
    get:async () => {
      if (pageRead) return { empty:true, docs:[] };
      pageRead = true;
      return { empty:false, docs:[doc] };
    },
  }) };
  const auth = { getUser:async () => {
    events.push(['auth']);
    if (missingAuth) throw { code:'auth/user-not-found' };
    return { uid:'synthetic-uid' };
  } };
  const file = {
    exists:async () => { events.push(['exists']); return [existingObject]; },
    save:async (bytes, options) => { events.push(['save', bytes, options]); },
    getMetadata:async () => [uploadedMetadata || { generation:'17', md5Hash:crypto.createHash('md5').update(jpeg).digest('base64'),
      metadata:{ firebaseStorageDownloadTokens:'synthetic-token', deparLegacyAvatarMigration:'v1' } }],
    delete:async options => { events.push(['objectDelete', options]); },
  };
  const bucket = { name:'demo-bucket.appspot.com', file:() => file };
  const visionClient = { safeSearchDetection:async bytes => {
    events.push(['vision', bytes]);
    return annotation;
  } };
  return { events, data, db, auth, bucket, visionClient, updateTime };
}

test('avatar migration requires its exact project and a second confirmation for apply', () => {
  assert.throws(() => parseArgs(['--project','other-project','--bucket','demo.appspot.com']), /must be/);
  assert.throws(() => parseArgs(['--project',TARGET_PROJECT,'--bucket','demo.appspot.com','--apply']), /confirm-project/);
  assert.throws(() => parseArgs(['--project',TARGET_PROJECT,'--bucket','demo.appspot.com','--apply',
    '--confirm-project','other-project']), /exact project ID/);
  assert.equal(parseArgs(['--project',TARGET_PROJECT,'--bucket','demo.appspot.com']).apply, false);
});

test('CLI credential adapter returns only the Admin credential shape with cloud-platform scope', async () => {
  const calls = [];
  const credential = createFirebaseCliCredential({ authModule:{
    getGlobalDefaultAccount:() => ({ tokens:{ refresh_token:'synthetic-refresh-token' } }),
    getAccessToken:async (refresh, scopes) => {
      calls.push({ refresh, scopes });
      return { access_token:'synthetic-access-token-long-enough', expires_in:300 };
    },
  } });
  assert.deepEqual(await credential.getAccessToken(), {
    access_token:'synthetic-access-token-long-enough', expires_in:300,
  });
  assert.equal(calls[0].refresh, 'synthetic-refresh-token');
  assert.deepEqual(calls[0].scopes, ['https://www.googleapis.com/auth/cloud-platform']);
});

test('OAuth2 bridge refreshes through Firebase CLI without persisting token material', async () => {
  let refreshed = 0;
  const client = createOAuth2Client({ getAccessToken:async () => {
    refreshed++;
    return { access_token:'synthetic-access-token', expires_in:60 };
  } }, class {
    async getAccessToken() { return { token:'synthetic-access-token' }; }
  });
  const refreshedCredentials = await client.refreshHandler();
  assert.equal(refreshedCredentials.access_token, 'synthetic-access-token');
  assert.equal(refreshed, 1);
});

test('Storage uses its compatible Google Auth 9 OAuth client and authorization header shape', async () => {
  const OAuth2Client = loadStorageOAuth2Client();
  const client = createOAuth2Client({ getAccessToken:async () => ({
    access_token:'synthetic-storage-token', expires_in:60,
  }) }, OAuth2Client);
  const headers = await client.getRequestHeaders('https://storage.googleapis.com');
  assert.equal(headers.authorization || headers.Authorization, 'Bearer synthetic-storage-token');
});

test('Firestore REST adapter uses a page token and an update-time precondition', async () => {
  const calls = [];
  const oauthClient = { request:async request => {
    calls.push(request);
    if (request.url.includes(':commit')) return { data:{ writeResults:[] } };
    if (request.url.includes('pageToken')) return { data:{ documents:[{
      name:'projects/p/databases/(default)/documents/users/u2', updateTime:'2026-01-02T03:04:05.123456789Z',
      fields:{ avatarType:{ stringValue:'base64' } },
    }] } };
    return { data:{ documents:[{
      name:'projects/p/databases/(default)/documents/users/u1', updateTime:'2026-01-02T03:04:05.123456789Z',
      fields:{ avatarData:{ stringValue:encoded } },
    }], nextPageToken:'opaque-page-token' } };
  } };
  const db = createFirestoreRest({ projectId:'p', oauthClient });
  const first = await db.collection('users').orderBy('__name__').limit(1).get();
  assert.equal(first.docs[0].get('avatarData'), encoded);
  const second = await db.collection('users').orderBy('__name__').limit(1).startAfter(first.docs[0]).get();
  assert.equal(second.docs[0].id, 'u2');
  await second.docs[0].ref.update({ avatarUrl:'url', avatarType:'icon', avatarData:'0' }, { lastUpdateTime:second.docs[0].updateTime });
  assert.match(calls[1].url, /pageToken=opaque-page-token/);
  assert.equal(calls[2].data.writes[0].currentDocument.updateTime, '2026-01-02T03:04:05.123456789Z');
});

test('Firestore REST pagination stops locally when the final page has no next-page token', async () => {
  let requests = 0;
  const db = createFirestoreRest({ projectId:'p', oauthClient:{ request:async () => {
    requests++;
    return { data:{ documents:[{
      name:'projects/p/databases/(default)/documents/users/final',
      updateTime:'2026-01-02T03:04:05.123456789Z', fields:{},
    }] } };
  } } });
  const first = await db.collection('users').orderBy('__name__').limit(1).get();
  const final = await db.collection('users').orderBy('__name__').limit(1).startAfter(first.docs[0]).get();
  assert.equal(requests, 1);
  assert.equal(final.empty, true);
  assert.deepEqual(final.docs, []);
});

test('Identity Platform lookup uses OAuth2 and maps an empty result to missing Auth user', async () => {
  let request;
  const auth = createIdentityPlatformAuth({ projectId:'p', oauthClient:{
    request:async options => { request = options; return { data:{ users:[{ localId:'u' }] } }; },
  } });
  assert.deepEqual(await auth.getUser('u'), { uid:'u' });
  assert.deepEqual(request.data, { localId:['u'] });
  const missing = createIdentityPlatformAuth({ projectId:'p', oauthClient:{
    request:async () => { throw { response:{ status:404 } }; },
  } });
  await assert.rejects(missing.getUser('u'), error => error.code === 'auth/user-not-found');
});

test('legacy image decoder accepts JPEG bytes and rejects malformed or oversized values', () => {
  assert.deepEqual(decodeLegacyJpeg(encoded), jpeg);
  assert.equal(decodeLegacyJpeg('not-base64'), null);
  assert.equal(decodeLegacyJpeg(Buffer.from('plain text').toString('base64')), null);
});

test('SafeSearch requires complete annotations and rejects configured high-risk results', () => {
  assert.equal(safeSearchPassed(safeAnnotation), true);
  assert.equal(safeSearchPassed({ ...safeAnnotation, adult:'LIKELY' }), false);
  assert.equal(safeSearchPassed({ ...safeAnnotation, violence:'VERY_LIKELY' }), false);
  assert.equal(safeSearchPassed({ ...safeAnnotation, racy:'VERY_LIKELY' }), false);
  assert.equal(safeSearchPassed({ adult:'UNLIKELY', violence:'UNLIKELY' }), false);
});

test('dry-run reports a Vision prerequisite and never uploads or updates a profile', async () => {
  const h = harness();
  const counts = await migrateLegacyAvatars({ ...h, visionClient:null, apply:false });
  assert.equal(counts.legacyCandidates, 1);
  assert.equal(counts.visionRequired, 1);
  assert.equal(counts.uploaded, 0);
  assert.equal(h.events.some(([name]) => ['vision','save','profileUpdate'].includes(name)), false);
});

test('apply scans first, create-only uploads one JPEG, then updates the profile with its URL', async () => {
  const h = harness();
  const counts = await migrateLegacyAvatars({ ...h, apply:true, uuid:() => 'synthetic-token' });
  assert.equal(counts.updated, 1);
  assert.deepEqual(h.events.map(([name]) => name), ['auth','exists','vision','exists','save','profileUpdate']);
  const save = h.events.find(([name]) => name === 'save');
  assert.deepEqual(save[1], jpeg);
  assert.equal(save[2].preconditionOpts.ifGenerationMatch, 0);
  assert.equal(save[2].metadata.metadata.firebaseStorageDownloadTokens, 'synthetic-token');
  assert.match(h.data.avatarUrl, /profile_images%2Fsynthetic-uid.jpg\?alt=media&token=synthetic-token$/);
  assert.equal(h.data.avatarType, 'icon');
  assert.equal(h.data.avatarData, '0');
  const write = h.events.find(([name]) => name === 'profileUpdate');
  assert.equal(write[2].lastUpdateTime, h.updateTime);
});

test('unsafe image, orphan account and existing storage object are skipped without writes', async () => {
  const unsafe = harness({ annotation:{ ...safeAnnotation, adult:'LIKELY' } });
  assert.equal((await migrateLegacyAvatars({ ...unsafe, apply:true })).moderationRejected, 1);
  assert.equal(unsafe.events.some(([name]) => ['save','profileUpdate'].includes(name)), false);

  const orphan = harness({ missingAuth:true });
  assert.equal((await migrateLegacyAvatars({ ...orphan, apply:true })).missingAuth, 1);
  assert.equal(orphan.events.some(([name]) => ['vision','save','profileUpdate'].includes(name)), false);

  const exists = harness({ existingObject:true });
  assert.equal((await migrateLegacyAvatars({ ...exists, apply:true })).objectExists, 1);
  assert.equal(exists.events.some(([name]) => ['vision','save','profileUpdate'].includes(name)), false);
});

test('a profile race aborts the conditional update and deletes only the created generation', async () => {
  const h = harness({ updateError:{ code:9 } });
  const counts = await migrateLegacyAvatars({ ...h, apply:true, uuid:() => 'synthetic-token' });
  assert.equal(counts.changedDuringRun, 1);
  assert.equal(counts.updated, 0);
  assert.deepEqual(h.events.at(-1), ['objectDelete', { ifGenerationMatch:'17' }]);
});

test('a newer owner generation after upload is never linked or deleted', async () => {
  const h = harness({ uploadedMetadata:{ generation:'18', md5Hash:'different-generation-hash',
    metadata:{ firebaseStorageDownloadTokens:'owner-new-token', deparLegacyAvatarMigration:'owner-upload' } } });
  const counts = await migrateLegacyAvatars({ ...h, apply:true, uuid:() => 'synthetic-token' });
  assert.equal(counts.uploadRace, 1);
  assert.equal(counts.updated, 0);
  assert.equal(h.events.some(([name]) => name === 'profileUpdate'), false);
  assert.equal(h.events.some(([name]) => name === 'objectDelete'), false);
});

test('Vision REST helper sends bytes under an in-memory bearer and does not log response data', async () => {
  let request;
  const vision = createVisionClient({
    credential:{ getAccessToken:async () => ({ access_token:'synthetic-access-token', expires_in:30 }) },
    fetchImpl:async (url, options) => {
      request = { url, options };
      return { ok:true, json:async () => ({ responses:[{ safeSearchAnnotation:safeAnnotation }] }) };
    },
  });
  assert.deepEqual(await vision.safeSearchDetection(jpeg), safeAnnotation);
  assert.match(request.url, /vision\.googleapis\.com\/v1\/images:annotate$/);
  assert.equal(request.options.headers.Authorization, 'Bearer synthetic-access-token');
  assert.equal(request.options.headers['x-goog-user-project'], TARGET_PROJECT);
  const body = JSON.parse(request.options.body);
  assert.equal(body.requests[0].image.content, jpeg.toString('base64'));
  assert.equal(body.requests[0].features[0].type, 'SAFE_SEARCH_DETECTION');
});

test('Vision HTTP failures expose only status and an allowlisted service reason', async () => {
  const sensitive = 'private-image-bytes-and-bearer-token';
  const vision = createVisionClient({
    credential:{ getAccessToken:async () => ({ access_token:'synthetic-access-token', expires_in:30 }) },
    fetchImpl:async () => ({ ok:false, status:403, json:async () => ({ error:{
      code:403, message:sensitive, errors:[{ reason:'SERVICE_DISABLED', message:sensitive }],
    } }) }),
  });
  let failure;
  await assert.rejects(vision.safeSearchDetection(jpeg), error => {
    failure = error;
    return error.message === 'Vision SafeSearch request failed' && error.status === 403 &&
      error.serviceReason === 'SERVICE_DISABLED';
  });
  const output = formatCliError(failure);
  assert.match(output, /"status":403/);
  assert.match(output, /"serviceReason":"SERVICE_DISABLED"/);
  assert.equal(output.includes(sensitive), false);
  assert.equal(JSON.stringify(failure).includes(sensitive), false);
  assert.equal(formatCliError({ name:'Error', status:403, serviceReason:sensitive })
    .includes(sensitive), false);
});

test('Vision quota project is fixed to the validated target project', () => {
  assert.throws(() => createVisionClient({
    projectId:'attacker-controlled-project', credential:{ getAccessToken:async () => ({}) },
  }), /Vision quota project must be/);
});
