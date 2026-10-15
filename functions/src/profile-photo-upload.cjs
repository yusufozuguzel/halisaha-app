const { randomUUID } = require('node:crypto');
const { HttpsError } = require('firebase-functions/v2/https');
const { identity, exactFields, requireEnabled } = require('./policy.cjs');
const { safeSearchResult } = require('./safe-search.cjs');

const MAX_BYTES = 5 * 1024 * 1024;
const RATE_INTERVAL_MS = 15_000;

function decodeImage(imageBase64, contentType) {
  if (!['image/jpeg', 'image/png', 'image/webp'].includes(contentType) ||
      typeof imageBase64 !== 'string' || imageBase64.length === 0 ||
      imageBase64.length > Math.ceil(MAX_BYTES / 3) * 4 ||
      !/^[A-Za-z0-9+/]*={0,2}$/.test(imageBase64) || imageBase64.length % 4 !== 0) {
    throw new HttpsError('invalid-argument', 'Fotoğraf biçimi geçersiz.');
  }
  const bytes = Buffer.from(imageBase64, 'base64');
  if (!bytes.length || bytes.length > MAX_BYTES || bytes.toString('base64') !== imageBase64) {
    throw new HttpsError('invalid-argument', 'Fotoğraf boyutu veya biçimi geçersiz.');
  }
  const valid = contentType === 'image/jpeg'
    ? bytes.length >= 3 && bytes[0] === 0xff && bytes[1] === 0xd8 && bytes[2] === 0xff
    : contentType === 'image/png'
      ? bytes.length >= 8 && bytes.subarray(0, 8).equals(Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]))
      : bytes.length >= 12 && bytes.toString('ascii', 0, 4) === 'RIFF' &&
        bytes.toString('ascii', 8, 12) === 'WEBP';
  if (!valid) throw new HttpsError('invalid-argument', 'Fotoğraf türü içerikle eşleşmiyor.');
  return bytes;
}

function isNotFound(error) { return Number(error?.code) === 404; }

function downloadTokens(metadata = {}) {
  const raw = metadata.metadata?.firebaseStorageDownloadTokens;
  if (typeof raw !== 'string') return [];
  return [...new Set(raw.split(',').map(token => token.trim())
    .filter(token => token.length > 0 && token.length <= 128 && /^[A-Za-z0-9_-]+$/.test(token)))].slice(0, 16);
}

function createProfilePhotoUploader({ db, auth, bucket, visionClient, enabled = false,
  now = Date.now, makeToken = randomUUID }) {
  async function ensureActive(uid) {
    const [job, restriction, user] = await Promise.all([
      db.doc(`accountDeletionJobs/${uid}`).get(),
      db.doc(`_moderationAccounts/${uid}`).get(),
      auth.getUser(uid),
    ]);
    if (job.exists) throw new HttpsError('failed-precondition', 'Hesap silme işlemi sürerken fotoğraf değiştirilemez.');
    if (restriction.exists) throw new HttpsError('permission-denied', 'Hesap kısıtlanmış.');
    if (!user || user.disabled) throw new HttpsError('permission-denied', 'Hesap kullanılamıyor.');
  }

  async function currentObjectState(file) {
    try {
      const [metadata] = await file.getMetadata();
      return { generation: String(metadata.generation), tokens: downloadTokens(metadata) };
    } catch (error) {
      if (isNotFound(error)) return null;
      throw error;
    }
  }

  async function reserveRateLimit(uid) {
    const ref = db.doc(`_profilePhotoLimits/${uid}`);
    const deletionJob = db.doc(`accountDeletionJobs/${uid}`);
    const restriction = db.doc(`_moderationAccounts/${uid}`);
    await db.runTransaction(async tx => {
      // Read account barriers in the same transaction as the rate-state write.
      const [snapshot, job, restricted] = await Promise.all([
        tx.get(ref), tx.get(deletionJob), tx.get(restriction),
      ]);
      if (job.exists) throw new HttpsError('failed-precondition', 'Hesap silme islemi suruyor.');
      if (restricted.exists) throw new HttpsError('permission-denied', 'Hesap kisitlanmis.');
      const requestAt = now();
      const last = snapshot.exists ? snapshot.get('lastRequestAtMs') : null;
      if (Number.isFinite(last) && requestAt - last < RATE_INTERVAL_MS) {
        throw new HttpsError('resource-exhausted', 'Bir sonraki fotoğrafı kısa süre sonra yükleyebilirsiniz.');
      }
      tx.set(ref, { lastRequestAtMs: requestAt, expiresAt: new Date(requestAt + RATE_INTERVAL_MS) });
    });
  }

  return async function uploadProfilePhoto(request) {
    requireEnabled(enabled);
    const uid = identity(request);
    exactFields(request.data, ['imageBase64', 'contentType']);
    const bytes = decodeImage(request.data.imageBase64, request.data.contentType);
    const objectPath = `profile_images/${uid}.jpg`;
    const file = bucket.file(objectPath);

    await ensureActive(uid);
    await reserveRateLimit(uid);
    const before = await currentObjectState(file);

    let result;
    try {
      [result] = await visionClient.safeSearchDetection({ image: { content: bytes } });
    } catch (_) {
      throw new HttpsError('unavailable', 'Fotoğraf denetlenemedi. Lütfen daha sonra tekrar deneyin.');
    }
    if (result?.error) throw new HttpsError('unavailable', 'Fotoğraf denetlenemedi. Lütfen daha sonra tekrar deneyin.');
    let moderation;
    try { moderation = safeSearchResult(result?.safeSearchAnnotation); }
    catch (_) { throw new HttpsError('unavailable', 'Fotoğraf denetlenemedi. Lütfen daha sonra tekrar deneyin.'); }
    if (!moderation.safe) throw new HttpsError('failed-precondition', 'Bu fotoğraf topluluk kurallarına uygun değil.');

    // Recheck identity/account barriers after the external scan and before any write.
    await ensureActive(uid);
    const after = await currentObjectState(file);
    if ((before?.generation ?? null) !== (after?.generation ?? null)) {
      throw new HttpsError('aborted', 'Profil fotoğrafı eşzamanlı olarak değişti. Lütfen tekrar deneyin.');
    }

    // Preserve existing download URLs when the same approved object is replaced,
    // including when the caller's later Firestore profile update fails.
    const tokens = after?.tokens.length ? after.tokens : [makeToken()];
    const token = tokens[0];
    try {
      await file.save(bytes, {
        resumable: false,
        preconditionOpts: { ifGenerationMatch: before?.generation ?? 0 },
        metadata: {
          contentType: request.data.contentType,
          metadata: { firebaseStorageDownloadTokens: tokens.join(',') },
        },
      });
    } catch (error) {
      if ([409, 412].includes(Number(error?.code))) {
        throw new HttpsError('aborted', 'Profil fotoğrafı eşzamanlı olarak değişti. Lütfen tekrar deneyin.');
      }
      throw new HttpsError('unavailable', 'Fotoğraf kaydedilemedi. Lütfen tekrar deneyin.');
    }
    const bucketName = bucket.name;
    const avatarUrl = `https://firebasestorage.googleapis.com/v0/b/${bucketName}/o/${encodeURIComponent(objectPath)}?alt=media&token=${token}`;
    return { avatarUrl };
  };
}

module.exports = { createProfilePhotoUploader, decodeImage, MAX_BYTES, RATE_INTERVAL_MS };
