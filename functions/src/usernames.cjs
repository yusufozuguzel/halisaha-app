const { FieldValue, Timestamp } = require('firebase-admin/firestore');
const { HttpsError } = require('firebase-functions/v2/https');
const { identity, exactFields, requireEnabled } = require('./policy.cjs');
const { publicTextAllowed } = require('./text-policy.cjs');

const USERNAME = /^[a-z0-9_]{3,30}$/;
const WINDOW_MS = 60_000;

function normalizeUsername(value) {
  if (typeof value !== 'string' || !USERNAME.test(value)) {
    throw new HttpsError('invalid-argument', 'Request could not be completed.');
  }
  return value;
}

function createUsernameService({ db, enabled = false, now = Date.now }) {
  async function rateLimit(uid, operation) {
    const window = Math.floor(now() / WINDOW_MS);
    const ref = db.doc(`_usernameLimits/${uid}/windows/${operation}_${window}`);
    const cap = operation === 'claim' ? 5 : 30;
    await db.runTransaction(async tx => {
      const snapshot = await tx.get(ref);
      const count = snapshot.exists ? snapshot.get('count') : 0;
      if (count >= cap) throw new HttpsError('resource-exhausted', 'Request could not be completed.');
      tx.set(ref, { count: count + 1, expiresAt: Timestamp.fromMillis((window + 2) * WINDOW_MS) });
    });
  }

  async function claim(request) {
    requireEnabled(enabled);
    const uid = identity(request);
    exactFields(request.data, ['username']);
    const username = normalizeUsername(request.data.username);
    if (!publicTextAllowed(username, 30)) throw new HttpsError('invalid-argument', 'Request could not be completed.');
    await rateLimit(uid, 'claim');
    const profile = db.doc(`users/${uid}`);
    const claimRef = db.doc(`_usernames/${username}`);
    const deletionJob = db.doc(`accountDeletionJobs/${uid}`);
    await db.runTransaction(async tx => {
      const restriction = db.doc(`_moderationAccounts/${uid}`);
      const [profileSnapshot, claimSnapshot, job, restricted] = await Promise.all([
        tx.get(profile), tx.get(claimRef), tx.get(deletionJob), tx.get(restriction),
      ]);
      if (!profileSnapshot.exists || profileSnapshot.get('profileVersion') !== 2 || job.exists || restricted.exists) {
        throw new HttpsError('failed-precondition', 'Request could not be completed.');
      }
      const existingUsername = profileSnapshot.get('username');
      if (typeof existingUsername === 'string' && existingUsername !== username) {
        throw new HttpsError('failed-precondition', 'Request could not be completed.');
      }
      if (claimSnapshot.exists && claimSnapshot.get('uid') !== uid) {
        throw new HttpsError('already-exists', 'Request could not be completed.');
      }
      if (!claimSnapshot.exists) {
        tx.create(claimRef, { uid, createdAt: FieldValue.serverTimestamp() });
      }
      if (existingUsername !== username) tx.update(profile, { username });
    });
    return { username };
  }

  async function find(request) {
    requireEnabled(enabled);
    const uid = identity(request);
    exactFields(request.data, ['username']);
    const username = normalizeUsername(request.data.username);
    await rateLimit(uid, 'find');
    const claim = await db.doc(`_usernames/${username}`).get();
    if (!claim.exists || typeof claim.get('uid') !== 'string') return { available: true };
    const ownerUid = claim.get('uid');
    if (!ownerUid || ownerUid.includes('/') || ownerUid.length > 128) return { available: false };
    const [profile, job] = await Promise.all([
      db.doc(`users/${ownerUid}`).get(), db.doc(`accountDeletionJobs/${ownerUid}`).get(),
    ]);
    if (!profile.exists || profile.get('profileVersion') !== 2 || profile.get('username') !== username || job.exists) {
      return { available: false };
    }
    return {
      available: false,
      uid: ownerUid,
      displayName: typeof profile.get('fullName') === 'string' ? profile.get('fullName') :
        (typeof profile.get('name') === 'string' ? profile.get('name') : ''),
    };
  }

  return { claim, find };
}

module.exports = { createUsernameService, normalizeUsername, USERNAME };
