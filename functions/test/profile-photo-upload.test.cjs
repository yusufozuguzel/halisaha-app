const { test } = require('node:test');
const assert = require('node:assert/strict');
const { createProfilePhotoUploader, MAX_BYTES } = require('../src/profile-photo-upload.cjs');

const jpeg = Buffer.from([0xff, 0xd8, 0xff, 0x01, 0x02]);
const request = {
  auth: { uid: 'alice' },
  data: { imageBase64: jpeg.toString('base64'), contentType: 'image/jpeg' },
};
const passed = { adult: 'UNLIKELY', violence: 'VERY_UNLIKELY', racy: 'POSSIBLE' };

function harness({ annotation = passed, visionError, incomplete = false, deleted = false,
  restricted = false, deletedDuringRateCheck = false, restrictedDuringRateCheck = false,
  disabledAfterVision = false, generation = null, existingTokens = '', generationAfterVision,
  saveError, now = 100_000, lastRequestAtMs, enabled = true } = {}) {
  const calls = { vision: [], saves: [], metadata: [], auth: 0, docReads: [], txReads: [], rateWrites: [] };
  let currentGeneration = generation;
  let clock = now;
  const db = {
    doc: path => ({ path }),
    runTransaction: async callback => callback({
      get: async ref => {
        calls.txReads.push(ref.path);
        if (ref.path === '_profilePhotoLimits/alice') {
          return { exists: lastRequestAtMs != null, get: key => key === 'lastRequestAtMs' ? lastRequestAtMs : undefined };
        }
        if (ref.path === 'accountDeletionJobs/alice') return { exists: deletedDuringRateCheck };
        if (ref.path === '_moderationAccounts/alice') return { exists: restrictedDuringRateCheck };
        return { exists: false };
      },
      set: (ref, value) => calls.rateWrites.push({ path: ref.path, value }),
    }),
  };
  const auth = { getUser: async uid => {
    calls.auth++;
    assert.equal(uid, 'alice');
    return { disabled: disabledAfterVision && calls.auth > 1 };
  } };
  const bucket = {
    name: 'example-bucket',
    file: path => {
      calls.objectPath = path;
      return {
        getMetadata: async () => {
          calls.metadata.push(path);
          if (currentGeneration == null) throw Object.assign(new Error('not found'), { code: 404 });
          return [{ generation: String(currentGeneration), metadata: { firebaseStorageDownloadTokens: existingTokens } }];
        },
        save: async (bytes, options) => {
          calls.saves.push({ bytes, options });
          if (generationAfterVision !== undefined && calls.metadata.length >= 2) currentGeneration = generationAfterVision;
          if (saveError) throw saveError;
          const expected = options.preconditionOpts.ifGenerationMatch;
          if (String(expected) !== String(currentGeneration ?? 0)) throw Object.assign(new Error('precondition'), { code: 412 });
          currentGeneration = String((Number(currentGeneration) || 0) + 1);
        },
      };
    },
  };
  const visionClient = { safeSearchDetection: async input => {
    calls.vision.push(input);
    if (generationAfterVision !== undefined) currentGeneration = generationAfterVision;
    if (visionError) throw visionError;
    return [{ safeSearchAnnotation: incomplete ? {} : annotation }];
  } };
  const upload = createProfilePhotoUploader({
    db: { ...db, doc: path => ({ path, get: async () => {
      calls.docReads.push(path);
      return { exists: path.startsWith('accountDeletionJobs/') ? deleted :
        path.startsWith('_moderationAccounts/') ? restricted : false };
    } }) },
    auth, bucket, visionClient, enabled, now: () => clock++, makeToken: () => 'generated-token',
  });
  return { upload, calls };
}

test('safe image is scanned before writing one canonical object and returns its download URL', async () => {
  const { upload, calls } = harness();
  const response = await upload(request);
  assert.equal(calls.objectPath, 'profile_images/alice.jpg');
  assert.deepEqual(calls.vision, [{ image: { content: jpeg } }]);
  assert.equal(calls.saves.length, 1);
  assert.equal(calls.saves[0].options.preconditionOpts.ifGenerationMatch, 0);
  assert.equal(calls.saves[0].options.metadata.contentType, 'image/jpeg');
  assert.deepEqual(calls.rateWrites[0], {
    path: '_profilePhotoLimits/alice',
    value: { lastRequestAtMs: 100_000, expiresAt: new Date(115_000) },
  });
  assert.match(response.avatarUrl, /^https:\/\/firebasestorage\.googleapis\.com\/v0\/b\/example-bucket\/o\/profile_images%2Falice\.jpg\?alt=media&token=generated-token$/);
  assert.equal(calls.auth, 2, 'account auth is checked both before and after Vision');
});

test('replacement preserves existing valid download tokens and uses the observed generation precondition', async () => {
  const { upload, calls } = harness({ generation: '12', existingTokens: 'persisted-token,second_token,invalid token' });
  const response = await upload(request);
  assert.equal(calls.saves.length, 1);
  assert.equal(calls.saves[0].options.preconditionOpts.ifGenerationMatch, '12');
  assert.equal(calls.saves[0].options.metadata.metadata.firebaseStorageDownloadTokens, 'persisted-token,second_token');
  assert.match(response.avatarUrl, /[?&]token=persisted-token$/);
});

test('Vision outage, malformed annotation, and unsafe detections make no Storage writes', async () => {
  for (const options of [
    { visionError: new Error('sensitive response body') },
    { incomplete: true },
    { annotation: { ...passed, violence: 'LIKELY' } },
  ]) {
    const { upload, calls } = harness(options);
    await assert.rejects(upload(request));
    assert.equal(calls.saves.length, 0);
  }
});

test('caller UID fields are rejected and unauthenticated requests cannot upload', async () => {
  const { upload, calls } = harness();
  await assert.rejects(upload({ ...request, data: { ...request.data, uid: 'victim' } }), { code: 'invalid-argument' });
  await assert.rejects(upload({ ...request, auth: null }), { code: 'unauthenticated' });
  assert.equal(calls.vision.length, 0);
  assert.equal(calls.saves.length, 0);
});

test('deleting or restricted account is rejected before Vision and Storage', async () => {
  for (const options of [{ deleted: true }, { restricted: true }]) {
    const { upload, calls } = harness(options);
    await assert.rejects(upload(request));
    assert.equal(calls.vision.length, 0);
    assert.equal(calls.saves.length, 0);
  }
});

test('rate-limit transaction reads deletion and moderation barriers before writing counter state', async () => {
  for (const options of [{ deletedDuringRateCheck: true }, { restrictedDuringRateCheck: true }]) {
    const { upload, calls } = harness(options);
    await assert.rejects(upload(request));
    assert.deepEqual(calls.txReads, [
      '_profilePhotoLimits/alice', 'accountDeletionJobs/alice', '_moderationAccounts/alice',
    ]);
    assert.equal(calls.rateWrites.length, 0);
    assert.equal(calls.vision.length, 0);
    assert.equal(calls.saves.length, 0);
  }
});

test('account state is rechecked after Vision before the Storage write', async () => {
  const { upload, calls } = harness({ disabledAfterVision: true });
  await assert.rejects(upload(request));
  assert.equal(calls.auth, 2);
  assert.equal(calls.saves.length, 0);
});

test('invalid MIME, forged signatures, malformed base64 and oversized images are rejected', async () => {
  const { upload, calls } = harness();
  const badRequests = [
    { ...request.data, contentType: 'image/gif' },
    { ...request.data, imageBase64: Buffer.from('not an image').toString('base64') },
    { ...request.data, imageBase64: '!!!!' },
    { ...request.data, imageBase64: Buffer.alloc(MAX_BYTES + 1, 1).toString('base64') },
  ];
  for (const data of badRequests) await assert.rejects(upload({ ...request, data }), { code: 'invalid-argument' });
  assert.equal(calls.vision.length, 0);
  assert.equal(calls.saves.length, 0);
});

test('newer object generation detected after scanning is never overwritten', async () => {
  const { upload, calls } = harness({ generation: '12', generationAfterVision: '13' });
  await assert.rejects(upload(request), { code: 'aborted' });
  assert.equal(calls.saves.length, 0);
});

test('Storage generation precondition protects a race after the final metadata check', async () => {
  const { upload, calls } = harness({ generation: '12', saveError: Object.assign(new Error('precondition'), { code: 412 }) });
  await assert.rejects(upload(request), { code: 'aborted' });
  assert.equal(calls.saves.length, 1);
  assert.equal(calls.saves[0].options.preconditionOpts.ifGenerationMatch, '12');
});

test('per-account upload rate limit is enforced and readiness defaults fail closed', async () => {
  const limited = harness({ lastRequestAtMs: 99_999 });
  await assert.rejects(limited.upload(request), { code: 'resource-exhausted' });
  assert.equal(limited.calls.vision.length, 0);
  const disabled = harness({ enabled: false });
  await assert.rejects(disabled.upload(request), { code: 'unavailable' });
  assert.equal(disabled.calls.vision.length, 0);
  assert.equal(disabled.calls.saves.length, 0);
});
