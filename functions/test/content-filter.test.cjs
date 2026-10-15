const { test } = require('node:test');
const assert = require('node:assert/strict');
const { createContentFilter } = require('../src/content-filter.cjs');

const token = 'event-token';
const url = `https://firebasestorage.googleapis.com/v0/b/demo-bucket/o/profile_images%2Falice.jpg?alt=media&token=${token}`;

function harness({ generation = '7', afterGeneration, detections = {}, visionError, missingAnnotation = false, metadataMissing = false, txUrl = url } = {}) {
  const calls = { analyzed: [], deletes: [], userUpdates: [] };
  let metadataCalls = 0;
  const file = {
    getMetadata: async () => {
      if (metadataMissing) throw Object.assign(new Error('missing object'), { code: 404 });
      metadataCalls++;
      return [{ generation: metadataCalls > 1 && afterGeneration ? afterGeneration : generation,
        metadata: { firebaseStorageDownloadTokens: token } }];
    },
    download: async () => [Buffer.from('image bytes')],
    delete: async options => { calls.deletes.push(options); },
  };
  const db = {
    collection: name => ({ doc: id => ({ name, id }) }),
    runTransaction: async callback => callback({
      get: async () => ({ exists: true, get: field => field === 'avatarUrl' ? txUrl : undefined }),
      update: (ref, data) => calls.userUpdates.push({ ref, data }),
    }),
  };
  const storage = { bucket: name => ({
    file: (path, options) => options?.generation ? { ...file, generation: options.generation } : file,
  }) };
  const visionClient = { safeSearchDetection: async request => {
    calls.analyzed.push(request);
    if (visionError) throw visionError;
    return [{ ...(missingAnnotation ? {} : { safeSearchAnnotation: detections }) }];
  } };
  return {
    calls,
    filter: createContentFilter({ visionClient, db, storage }),
  };
}

const event = { name: 'profile_images/alice.jpg', bucket: 'demo-bucket', generation: '7' };

test('Vision errors and incomplete results reject so the retryable trigger can retry', async () => {
  for (const options of [
    { visionError: new Error('Vision unavailable') },
    { missingAnnotation: true },
    { detections: {} },
    { detections: { adult: 'UNLIKELY', violence: 'UNLIKELY' } },
    { detections: { adult: 'UNLIKELY', violence: 'UNLIKELY', racy: 'MAYBE' } },
    { detections: { adult: 'UNKNOWN', violence: 'UNLIKELY', racy: 'UNLIKELY' } },
  ]) {
    const { filter, calls } = harness(options);
    await assert.rejects(filter(event));
    assert.equal(calls.deletes.length, 0);
    assert.equal(calls.userUpdates.length, 0);
  }
});

test('safe image is analyzed from the event generation bytes and retained', async () => {
  const { filter, calls } = harness({ detections: { adult: 'UNLIKELY', violence: 'UNLIKELY', racy: 'UNLIKELY' } });
  assert.deepEqual(await filter(event), { action: 'passed' });
  assert.deepEqual(calls.analyzed[0], { image: { content: Buffer.from('image bytes') } });
  assert.equal(calls.deletes.length, 0);
});

test('superseded event is ignored without analyzing, deleting, or clearing the newer profile', async () => {
  const { filter, calls } = harness({ generation: '8', detections: { adult: 'VERY_LIKELY' } });
  assert.deepEqual(await filter(event), { action: 'superseded' });
  assert.equal(calls.analyzed.length, 0);
  assert.equal(calls.deletes.length, 0);
  assert.equal(calls.userUpdates.length, 0);
});

test('inappropriate image deletion is generation-guarded and clears only its matching avatar URL', async () => {
  const { filter, calls } = harness({ detections: { adult: 'VERY_LIKELY', violence: 'UNLIKELY', racy: 'UNLIKELY' } });
  assert.deepEqual(await filter(event), { action: 'deleted', reason: 'inappropriate_content' });
  assert.deepEqual(calls.deletes, [{ ifGenerationMatch: '7' }]);
  assert.equal(calls.userUpdates.length, 1);
  assert.deepEqual(calls.userUpdates[0].data, { avatarUrl: '', avatarData: '0', avatarType: 'icon' });
});

test('deleting an old avatar never clears a newer token URL', async () => {
  const newerUrl = url.replace(token, 'newer-token');
  const { filter, calls } = harness({ detections: { adult: 'UNLIKELY', violence: 'UNLIKELY', racy: 'VERY_LIKELY' }, txUrl: newerUrl });
  assert.deepEqual(await filter(event), { action: 'deleted', reason: 'inappropriate_content' });
  assert.deepEqual(calls.deletes, [{ ifGenerationMatch: '7' }]);
  assert.equal(calls.userUpdates.length, 0);
});

test('a retry after object deletion completes the matching Firestore cleanup idempotently', async () => {
  const { filter, calls } = harness({ metadataMissing: true });
  assert.deepEqual(await filter({ ...event, metadata: { firebaseStorageDownloadTokens: token } }), { action: 'superseded' });
  assert.equal(calls.deletes.length, 0);
  assert.equal(calls.userUpdates.length, 1);
});

test('a reused Firebase download token cannot clear a profile after a newer generation appears', async () => {
  const { filter, calls } = harness({ generation: '7', afterGeneration: '8', detections: { adult: 'VERY_LIKELY', violence: 'UNLIKELY', racy: 'UNLIKELY' } });
  assert.deepEqual(await filter(event), { action: 'deleted', reason: 'inappropriate_content' });
  assert.deepEqual(calls.deletes, [{ ifGenerationMatch: '7' }]);
  assert.equal(calls.userUpdates.length, 0);
});

test('unused match_images branch is ignored', async () => {
  const { filter, calls } = harness();
  assert.equal(await filter({ ...event, name: 'match_images/game.jpg' }), null);
  assert.equal(calls.analyzed.length, 0);
});

test('matching paths or tokens on unrelated URLs never clear the selected avatar', async () => {
  const foreignUrls = [
    url.replace('firebasestorage.googleapis.com', 'example.invalid'),
    url.replace('https:', 'http:'),
    url.replace('googleapis.com/', 'googleapis.com:8443/'),
    `${url}#unrelated`,
    url.replace('alt=media', 'alt=json'),
  ];
  for (const txUrl of foreignUrls) {
    const { filter, calls } = harness({ txUrl,
      detections: { adult:'VERY_LIKELY', violence:'UNLIKELY', racy:'UNLIKELY' } });
    assert.deepEqual(await filter(event), { action:'deleted', reason:'inappropriate_content' });
    assert.equal(calls.userUpdates.length, 0);
  }
});
