const { getFirestore } = require('firebase-admin/firestore');
const { getStorage } = require('firebase-admin/storage');
const { safeSearchResult } = require('./safe-search.cjs');

const isSuperseded = error => [404, 412].includes(Number(error?.code));

function profileUid(filePath) {
  const match = /^profile_images\/([^/]+)\.jpg$/.exec(filePath);
  return match?.[1] || null;
}

function downloadTokens(metadata = {}) {
  const custom = metadata.metadata || metadata;
  return new Set(String(custom.firebaseStorageDownloadTokens || '')
    .split(',').map(token => token.trim()).filter(Boolean));
}

function profilePhotoUrlMatches(url, bucketName, filePath, tokens) {
  if (typeof url !== 'string' || !tokens.size) return false;
  try {
    const parsed = new URL(url);
    const expectedPath = `/v0/b/${bucketName}/o/${encodeURIComponent(filePath)}`;
    return parsed.protocol === 'https:' && parsed.hostname === 'firebasestorage.googleapis.com'
      && !parsed.port && !parsed.username && !parsed.password && !parsed.hash
      && parsed.pathname === expectedPath && parsed.searchParams.get('alt') === 'media'
      && tokens.has(parsed.searchParams.get('token'));
  } catch (_) {
    return false;
  }
}

function createContentFilter({ visionClient, db, storage }) {
  async function clearDeletedProfileUrl(uid, bucketName, filePath, generation, metadata) {
    const tokens = downloadTokens(metadata);
    if (!tokens.size) return;
    const ref = db.collection('users').doc(uid);
    await db.runTransaction(async tx => {
      const user = await tx.get(ref);
      if (!user.exists || !profilePhotoUrlMatches(user.get('avatarUrl'), bucketName, filePath, tokens)) return;
      try {
        const [current] = await storage.bucket(bucketName).file(filePath).getMetadata();
        if (String(current.generation) !== String(generation)) return;
      } catch (error) {
        if (Number(error?.code) !== 404) throw error;
      }
      tx.update(ref, { avatarUrl: '', avatarData: '0', avatarType: 'icon' });
    });
  }

  return async function filterImage(rawEvent) {
    const object = rawEvent?.data || rawEvent || {};
    const filePath = object.name;
    const bucketName = object.bucket;
    const generation = object.generation;
    const uid = typeof filePath === 'string' ? profileUid(filePath) : null;

    // Storage rules currently permit only profile_images/{uid}.jpg.
    if (!uid) return null;
    if (!bucketName || !generation) throw new Error('Image event is missing bucket or generation');

    const bucket = storage.bucket(bucketName);
    const file = bucket.file(filePath, { generation: String(generation) });
    let metadata;
    try {
      [metadata] = await bucket.file(filePath).getMetadata();
    } catch (error) {
      if (Number(error?.code) === 404) {
        // A prior attempt may have deleted this exact object and then failed
        // while updating Firestore. The immutable event token still lets the
        // retry clear only the stale pointer, never a newer URL.
        await clearDeletedProfileUrl(uid, bucketName, filePath, generation, object);
        return { action: 'superseded' };
      }
      if (Number(error?.code) === 412) return { action: 'superseded' };
      throw error;
    }
    if (String(metadata.generation) !== String(generation)) return { action: 'superseded' };

    let bytes;
    try {
      [bytes] = await file.download();
    } catch (error) {
      if (isSuperseded(error)) return { action: 'superseded' };
      throw error;
    }

    // Analyze the event's immutable bytes, not whichever image currently occupies
    // the reusable profile path. API and incomplete-response errors must retry.
    const [result] = await visionClient.safeSearchDetection({ image: { content: bytes } });
    if (result?.error) throw new Error('Vision returned an image analysis error');
    if (safeSearchResult(result?.safeSearchAnnotation).safe) return { action: 'passed' };

    try {
      await file.delete({ ifGenerationMatch: String(generation) });
    } catch (error) {
      if (isSuperseded(error)) return { action: 'superseded' };
      throw error;
    }
    await clearDeletedProfileUrl(uid, bucketName, filePath, generation, metadata);
    return { action: 'deleted', reason: 'inappropriate_content' };
  };
}

let client;
const filterImage = (...args) => {
  if (!client) {
    const vision = require('@google-cloud/vision');
    client = new vision.ImageAnnotatorClient();
  }
  return createContentFilter({ visionClient: client, db: getFirestore(), storage: getStorage() })(...args);
};

module.exports = { createContentFilter, filterImage, profilePhotoUrlMatches };
