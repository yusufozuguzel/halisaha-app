const { createHash, randomUUID } = require('node:crypto');
const { FieldValue, FieldPath } = require('firebase-admin/firestore');
const { HttpsError } = require('firebase-functions/v2/https');
const { identity, exactFields, requireEnabled, referencesUser, matchCleanup } = require('./policy.cjs');

const groups = ['friends', 'followRequests', 'followers', 'following', 'notifications'];

function createSafetyService({ db, auth, bucket, deletionEnabled = false, reportsEnabled = false, pageSize = 100 }) {
  const jobs = db.collection('accountDeletionJobs');

  async function activeAccounts(tx, uids) {
    for (const uid of new Set(uids)) {
      if (typeof uid !== 'string' || !uid || uid.includes('/') || uid.length > 128) {
        throw new HttpsError('failed-precondition', 'Hesap bilgisi doğrulanamadı.');
      }
      if ((await tx.get(jobs.doc(uid))).exists) {
        throw new HttpsError('unavailable', 'Bu hesap için işlem yapılamıyor.');
      }
    }
  }
  async function activeTarget(tx, type, targetId) {
    const target = await tx.get(db.collection(type === 'user' ? 'users' : 'matches').doc(targetId));
    if (!target.exists) throw new HttpsError('not-found', 'İçerik bulunamadı.');
    const owner = type === 'user' ? targetId : target.data().createdBy || target.data().creatorId;
    await activeAccounts(tx, [owner]);
    return target;
  }

  async function prepareDeletion(request) {
    requireEnabled(deletionEnabled);
    identity(request, { recent: true });
    exactFields(request.data, []);
    return { ready: true };
  }

  async function requestDeletion(request) {
    requireEnabled(deletionEnabled);
    const uid = identity(request, { recent: true });
    exactFields(request.data, []);
    const ref = jobs.doc(uid);
    await db.runTransaction(async tx => {
      const existing = await tx.get(ref);
      if (existing.exists) return; // Stable idempotency key: authenticated UID.
      tx.create(ref, { status: 'pending', stage: 'matches', cursor: null, createdAt: FieldValue.serverTimestamp() });
    });
    return { accepted: true };
  }

  async function submitReport(request) {
    requireEnabled(reportsEnabled);
    const uid = identity(request);
    exactFields(request.data, ['type', 'targetId', 'reason']);
    const { type, targetId, reason } = request.data;
    if (!['user', 'match'].includes(type) || typeof targetId !== 'string' ||
        !targetId || targetId.length > 128 || targetId.includes('/') ||
        !['harassment', 'inappropriateContent', 'spam', 'other'].includes(reason) ||
        (type === 'user' && targetId === uid)) {
      throw new HttpsError('invalid-argument', 'Geçersiz şikayet.');
    }
    const throttle = db.collection('_reportLimits').doc(uid);
    await db.runTransaction(async tx => {
      await activeAccounts(tx, [uid]);
      const target = await activeTarget(tx, type, targetId);
      // Dedupe retries for this content version, but allow a new report if the
      // content changes after an earlier review/restoration.
      const version = `${target.updateTime.seconds}:${target.updateTime.nanoseconds}`;
      const id = createHash('sha256').update(JSON.stringify([uid, type, targetId, version])).digest('hex');
      const ref = db.collection('contentReports').doc(id);
      if ((await tx.get(ref)).exists) return; // Duplicate retry is successful, not a second report.
      const previous = (await tx.get(throttle)).data()?.lastCreatedAt;
      if (previous && Date.now() - previous.toMillis() < 60000) {
        throw new HttpsError('resource-exhausted', 'Yeni bir şikayet göndermeden önce bir dakika bekleyin.');
      }
      tx.create(ref, { type, targetId, reason, reporterId: uid, status: 'pending', createdAt: FieldValue.serverTimestamp() });
      tx.set(throttle, { lastCreatedAt: FieldValue.serverTimestamp() });
    });
    return { recorded: true };
  }

  async function reviewReport(request) {
    requireEnabled(reportsEnabled);
    const uid = identity(request, { recent: true });
    if (request.auth.token?.moderator !== true) throw new HttpsError('permission-denied', 'Yetkiniz yok.');
    exactFields(request.data, ['reportId', 'status']);
    const { reportId, status } = request.data;
    if (!/^[a-f0-9]{64}$/.test(reportId) || !['reviewing', 'dismissed', 'resolved'].includes(status)) {
      throw new HttpsError('invalid-argument', 'Geçersiz inceleme.');
    }
    await db.runTransaction(async tx => {
      await activeAccounts(tx, [uid]);
      const ref = db.collection('contentReports').doc(reportId);
      if ((await tx.get(db.doc(`_moderationAccounts/${uid}`))).exists) throw new HttpsError('permission-denied', 'Hesap kısıtlanmış.');
      const current = await tx.get(ref);
      if (!current.exists) throw new HttpsError('not-found', 'Şikayet bulunamadı.');
      if (status !== 'dismissed') {
        await activeAccounts(tx, [current.data().reporterId]);
        await activeTarget(tx, current.data().type, current.data().targetId);
      }
      const oldStatus = current.data().status;
      if (oldStatus === status) return;
      if (status === 'resolved') throw new HttpsError('failed-precondition', 'Önce moderasyon işlemini uygulayın.');
      if (!((oldStatus === 'pending' && ['reviewing', 'dismissed'].includes(status)) ||
            (oldStatus === 'reviewing' && ['dismissed', 'resolved'].includes(status)))) {
        throw new HttpsError('failed-precondition', 'Önce şikayeti incelemeye alın.');
      }
      tx.update(ref, { status, reviewedBy: uid, reviewedAt: FieldValue.serverTimestamp() });
    });
    return { updated: true };
  }

  async function listReports(request) {
    requireEnabled(reportsEnabled);
    const uid = identity(request, { recent: true });
    if (request.auth.token?.moderator !== true) throw new HttpsError('permission-denied', 'Yetkiniz yok.');
    exactFields(request.data, []);
    if ((await jobs.doc(uid).get()).exists) throw new HttpsError('unavailable', 'Bu hesap için işlem yapılamıyor.');
    if ((await db.doc(`_moderationAccounts/${uid}`).get()).exists) throw new HttpsError('permission-denied', 'Hesap kısıtlanmış.');
    const snapshot = await db.collection('contentReports').where('status', 'in', ['pending', 'reviewing']).limit(50).get();
    return { reports: snapshot.docs.map(doc => ({ id: doc.id, ...doc.data(), createdAt: doc.data().createdAt?.toMillis() ?? null })) };
  }

  async function clean(uid) {
    // This method is called only by the trusted Firestore trigger, never by a client-supplied UID.
    if (typeof uid !== 'string' || !uid || uid.includes('/')) throw new Error('Invalid deletion job');
    const job = jobs.doc(uid);
    let state = (await job.get()).data();
    if (!state || state.status === 'completed') return;
    await job.update({ status: 'processing' });

    const owned = job.collection('ownedMatches');
    async function relatedMatch(data) {
      return typeof data.matchId === 'string' && !data.matchId.includes('/') && data.matchId.length > 0 &&
        (await owned.doc(data.matchId).get()).exists;
    }
    async function pages(query, handle, nextStage) {
      let cursor = state.cursor;
      while (true) {
        let page = query.orderBy(FieldPath.documentId()).limit(pageSize);
        if (cursor) page = page.startAfter(db.doc(cursor));
        const snapshot = await page.get();
        if (snapshot.empty) break;
        for (const doc of snapshot.docs) await handle(doc);
        cursor = snapshot.docs.at(-1).ref.path;
        await job.update({ cursor }); // Save only after the whole page succeeds.
      }
      await job.update({ stage: nextStage, cursor: null });
      state = { ...state, stage: nextStage, cursor: null };
    }

    if (state.stage === 'matches') await pages(db.collection('matches'), async doc => {
      const isOwned = await db.runTransaction(async tx => {
        const latest = await tx.get(doc.ref);
        if (!latest.exists) return false;
        const data = latest.data();
        if (data.createdBy === uid || (!data.createdBy && data.creatorId === uid)) {
          // Reserve this ID before recursive deletion. It cannot be reused
          // while delayed notification/report cleanup still refers to it.
          tx.set(owned.doc(doc.id), {});
          tx.set(db.doc(`_retiredMatches/${doc.id}`), { retiredAt: FieldValue.serverTimestamp() });
          return true;
        }
        const patch = matchCleanup(data, uid);
        if (Object.keys(patch).length) tx.update(doc.ref, patch);
        return false;
      });
      if (isOwned) await db.recursiveDelete(doc.ref);
    }, 'users');

    if (state.stage === 'users') await pages(db.collection('users'), async doc => {
      if (doc.id === uid) return;
      await db.runTransaction(async tx => {
        const latest = await tx.get(doc.ref);
        if (latest.exists && latest.data().blockedUsers?.includes(uid)) {
          tx.update(doc.ref, { blockedUsers: FieldValue.arrayRemove(uid) });
        }
      });
    }, groups[0]);

    for (let index = 0; index < groups.length; index++) {
      const group = groups[index];
      if (state.stage !== group) continue;
      await pages(db.collectionGroup(group), async doc => {
        if ((group !== 'notifications' && doc.id === uid) || doc.ref.path.startsWith(`users/${uid}/`) ||
            referencesUser(doc.data(), uid) || await relatedMatch(doc.data())) {
          await db.recursiveDelete(doc.ref);
        }
      }, groups[index + 1] ?? 'reports');
    }

    if (state.stage === 'reports') await pages(db.collection('contentReports'), async doc => {
      await db.runTransaction(async tx => {
        const latest = await tx.get(doc.ref);
        if (!latest.exists) return;
        const data = latest.data();
        const ownedTarget = data.type === 'match' && typeof data.targetId === 'string'
          && data.targetId.length > 0 && !data.targetId.includes('/')
          && (await tx.get(owned.doc(data.targetId))).exists;
        if (data.reporterId === uid || (data.type === 'user' && data.targetId === uid) || ownedTarget) {
          tx.delete(doc.ref);
        } else {
          const patch = {};
          if (data.reviewedBy === uid) patch.reviewedBy = FieldValue.delete();
          if (data.restoredBy === uid) patch.restoredBy = FieldValue.delete();
          if (Object.keys(patch).length) tx.update(doc.ref, patch);
        }
      });
    }, 'storage');

    if (state.stage === 'storage') {
      const exactName = `profile_images/${uid}.jpg`;
      // Explicit object versions only; never delete another user's prefix.
      const [files] = await bucket.getFiles({ prefix: exactName, versions: true });
      for (const file of files) {
        if (file.name === exactName) {
          try { await file.delete(); } catch (error) { if (Number(error.code) !== 404) throw error; }
        }
      }
      await db.recursiveDelete(db.doc(`users/${uid}`));
      await db.doc(`_reportLimits/${uid}`).delete();
      await db.doc(`_moderationAccounts/${uid}`).delete();
      while (true) {
        const removals = await db.collection('_moderationRemovals').where('uid', '==', uid).limit(100).get();
        if (removals.empty) break;
        const batch = db.batch();
        for (const removal of removals.docs) batch.delete(removal.ref);
        await batch.commit();
      }
      await job.update({ stage: 'auth', cursor: null });
      state.stage = 'auth';
    }
    if (state.stage === 'auth') {
      try { await auth.deleteUser(uid); } catch (error) { if (error.code !== 'auth/user-not-found') throw error; }
      await db.recursiveDelete(owned);
      await job.update({ status: 'completed', stage: 'done', cursor: null, completedAt: FieldValue.serverTimestamp() });
    }
  }

  async function processDeletion(uid) {
    if (typeof uid !== 'string' || !uid || uid.includes('/')) throw new Error('Invalid deletion job');
    const ref = jobs.doc(uid);
    const owner = randomUUID();
    const acquired = await db.runTransaction(async tx => {
      const snap = await tx.get(ref);
      if (!snap.exists || snap.data().status === 'completed') return false;
      if ((snap.data().leaseUntil ?? 0) > Date.now()) throw new Error('Deletion job busy; retry required');
      tx.update(ref, { leaseOwner: owner, leaseUntil: Date.now() + 600000 });
      return true;
    });
    if (!acquired) return;
    try {
      await clean(uid);
    } finally {
      // Failure keeps this account's job/barrier and page cursor; only release the worker
      // lease. A process crash expires the lease after the function timeout.
      await db.runTransaction(async tx => {
        const snap = await tx.get(ref);
        if (snap.data()?.leaseOwner === owner) {
          tx.update(ref, { leaseOwner: FieldValue.delete(), leaseUntil: FieldValue.delete() });
        }
      });
    }
  }

  async function removeLateProfileUpload(object) {
    // Storage and Firestore are not one atomic system. A late upload must not
    // restore a deleted account's photo after the worker's listing has passed.
    const match = typeof object?.name === 'string' && /^profile_images\/([^/]+)\.jpg$/.exec(object.name);
    if (!match || match[1].length > 128 || object.bucket !== bucket.name) return;
    if (typeof object.generation !== 'string' || !/^\d+$/.test(object.generation)) throw new Error('Missing object generation');
    if (!(await jobs.doc(match[1]).get()).exists &&
        !(await db.doc(`_moderationAccounts/${match[1]}`).get()).exists) return;
    // Event retries delete only the exact finalized version, never a prefix
    // or a newer unrelated object's generation. No metadata-supplied UID used.
    try { await bucket.file(object.name, { generation:object.generation }).delete(); }
    catch (error) { if (Number(error.code) !== 404) throw error; }
  }

  return { prepareDeletion, requestDeletion, submitReport, listReports, reviewReport, processDeletion, removeLateProfileUpload };
}

module.exports = { createSafetyService };
