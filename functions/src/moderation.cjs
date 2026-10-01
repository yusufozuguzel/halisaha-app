const { FieldValue, FieldPath } = require('firebase-admin/firestore');
const { HttpsError } = require('firebase-functions/v2/https');
const { identity, exactFields, requireEnabled } = require('./policy.cjs');
const versionOf = doc => doc.exists ? `${doc.updateTime.seconds}:${doc.updateTime.nanoseconds}` : '';

// Restrictions stop client writes, not authentication. Reading, reporting and
// the authenticated account-deletion workflow remain available.
function createModerationService({ db, bucket, enabled = false }) {
  async function moderator(request, tx) {
    requireEnabled(enabled);
    const uid = identity(request, { recent: true });
    if (request.auth.token?.moderator !== true) throw new HttpsError('permission-denied', 'Yetkiniz yok.');
    const read = ref => tx ? tx.get(ref) : ref.get();
    for (const path of [`accountDeletionJobs/${uid}`, `_moderationAccounts/${uid}`]) {
      if ((await read(db.doc(path))).exists) throw new HttpsError('permission-denied', 'Bu hesap işlem yapamaz.');
    }
    return uid;
  }
  async function queue(request) {
    await moderator(request);
    exactFields(request.data, ['kind', 'after']);
    const { kind, after } = request.data;
    if (!['reports', 'restrictions'].includes(kind) || typeof after !== 'string' || after.length > 128 || after.includes('/')) {
      throw new HttpsError('invalid-argument', 'Geçersiz sayfa.');
    }
    let query = kind === 'reports'
      ? db.collection('contentReports').where('status', 'in', ['pending', 'reviewing'])
      : db.collection('_moderationAccounts');
    query = query.orderBy(FieldPath.documentId()).limit(51);
    if (after) query = query.startAfter(after);
    const snapshot = await query.get();
    const page = snapshot.docs.slice(0, 50);
    const items = await Promise.all(page.map(async doc => {
      const data = doc.data();
      if (kind === 'restrictions') return { id: doc.id, reportId: data.reportId,
        cleanupPending: !!data.cleanupReportId && (await db.doc(`_moderationRemovals/${data.cleanupReportId}`).get()).get('status') !== 'completed' };
      const target = await db.doc(`${data.type === 'user' ? 'users' : 'matches'}/${data.targetId}`).get();
      const content = target.data() ?? {};
      const short = value => typeof value === 'string' ? value.slice(0, 2048) : '';
      return { id: doc.id, type: data.type, targetId: data.targetId, reason: data.reason, status: data.status,
        version: versionOf(target),
        preview: { title: short(content.title ?? content.fullName ?? content.name),
          detail: short(content.venue ?? content.position), image: short(content.avatarUrl) } };
    }));
    return { items, next: snapshot.size > 50 ? page.at(-1).id : '' };
  }
  async function act(request) {
    await moderator(request);
    exactFields(request.data, ['reportId', 'action', 'version']);
    const { reportId, action, version } = request.data;
    if (typeof reportId !== 'string' || !/^[a-f0-9]{64}$/.test(reportId) ||
        !['removeMatch', 'restrictAccount', 'redactProfile'].includes(action) || typeof version !== 'string') {
      throw new HttpsError('invalid-argument', 'Geçersiz işlem.');
    }
    await db.runTransaction(async tx => {
      const uid = await moderator(request, tx);
      const ref = db.doc(`contentReports/${reportId}`);
      const report = (await tx.get(ref)).data();
      if (!report) throw new HttpsError('not-found', 'Şikayet bulunamadı.');
      const targetId = report.targetId;
      if (report.type === 'user' && targetId === uid) throw new HttpsError('permission-denied', 'Kendi hesabınızda işlem yapamazsınız.');
      if (report.status === 'resolved' && report.action === action) return;
      if (report.status !== 'reviewing' || (action === 'removeMatch') !== (report.type === 'match')) {
        throw new HttpsError('failed-precondition', 'Önce uygun şikayeti incelemeye alın.');
      }
      const target = db.doc(`${report.type === 'user' ? 'users' : 'matches'}/${targetId}`);
      const current = await tx.get(target);
      if (!current.exists || versionOf(current) !== version) {
        throw new HttpsError('failed-precondition', 'İçerik değişti. Yeniden inceleyin.');
      }
      const owner = report.type === 'user' ? targetId : current.get('createdBy') || current.get('creatorId');
      if (typeof owner !== 'string' || !owner || owner.includes('/') || (await tx.get(db.doc(`accountDeletionJobs/${owner}`))).exists) {
        throw new HttpsError('failed-precondition', 'Hesap silme işlemi sürüyor.');
      }
      if (action !== 'removeMatch') {
        const restriction = db.doc(`_moderationAccounts/${targetId}`);
        const existing = await tx.get(restriction);
        if (existing.exists && action === 'restrictAccount') throw new HttpsError('already-exists', 'Hesap zaten kısıtlanmış.');
        const previousCleanup = existing.data()?.cleanupReportId;
        if (previousCleanup && (await tx.get(db.doc(`_moderationRemovals/${previousCleanup}`))).get('status') !== 'completed') {
          throw new HttpsError('failed-precondition', 'Önceki profil temizliği sürüyor.');
        }
        tx.set(restriction, { ...(existing.data() ?? { reportId, createdAt: FieldValue.serverTimestamp() }),
          ...(action === 'redactProfile' ? { cleanupReportId: reportId } : {}) });
        if (action === 'redactProfile') {
          tx.update(target, { fullName:'Kullanıcı', name:'Kullanıcı', position:'', city:'',
            avatarUrl:'', avatarType:'icon', avatarData:'0',
            profileImageUrl:FieldValue.delete(), photoUrl:FieldValue.delete() });
          tx.create(db.doc(`_moderationRemovals/${reportId}`), { uid:targetId, status:'pending' });
        }
      } else {
        tx.set(db.doc(`_retiredMatches/${targetId}`), { retiredAt: FieldValue.serverTimestamp() });
        tx.create(db.doc(`_moderationRemovals/${reportId}`), { matchId: targetId, status: 'pending' });
        tx.delete(target);
      }
      tx.update(ref, { status: 'resolved', action, reviewedBy: uid, reviewedAt: FieldValue.serverTimestamp() });
    });
    return { updated: true };
  }
  async function restore(request) {
    await moderator(request);
    exactFields(request.data, ['uid', 'reportId']);
    const { uid, reportId } = request.data;
    if (typeof uid !== 'string' || !uid || uid.length > 128 || uid.includes('/') ||
        typeof reportId !== 'string' || !/^[a-f0-9]{64}$/.test(reportId)) {
      throw new HttpsError('invalid-argument', 'Geçersiz hesap.');
    }
    await db.runTransaction(async tx => {
      const reviewer = await moderator(request, tx);
      const ref = db.doc(`_moderationAccounts/${uid}`);
      const current = await tx.get(ref);
      const report = db.doc(`contentReports/${reportId}`);
      const source = await tx.get(report);
      if (!current.exists) return;
      const cleanup = current.get('cleanupReportId');
      if (cleanup && (await tx.get(db.doc(`_moderationRemovals/${cleanup}`))).get('status') !== 'completed') {
        throw new HttpsError('failed-precondition', 'Fotoğraf temizliği henüz tamamlanmadı.');
      }
      if (current.get('reportId') !== reportId) throw new HttpsError('failed-precondition', 'Kısıtlama değişti. Listeyi yenileyin.');
      tx.delete(ref);
      if (source.exists) tx.update(report, { restoredBy: reviewer, restoredAt: FieldValue.serverTimestamp() });
    });
    return { updated: true };
  }
  async function cleanupRemoval(reportId) {
    const job = db.doc(`_moderationRemovals/${reportId}`);
    const data = (await job.get()).data();
    if (!data || data.status === 'completed') return;
    if (data.uid) {
      if (typeof data.uid !== 'string' || data.uid.includes('/') || data.uid.length > 128) throw new Error('Invalid removal');
      const groups = ['friends','followers','following','followRequests','notifications'];
      let stage = data.stage ?? 'storage';
      let savedCursor = data.cursor;
      if (stage === 'storage') {
        const name = `profile_images/${data.uid}.jpg`;
        const [files] = await bucket.getFiles({ prefix:name, versions:true });
        for (const file of files) if (file.name === name) {
          try { await file.delete(); } catch (error) { if (Number(error.code) !== 404) throw error; }
        }
        stage = groups[0]; savedCursor = null;
        await job.update({stage, cursor:null});
      }
      // Stored relationship snapshots also contain profile display fields.
      for (let index=0; index<groups.length; index++) {
        const group = groups[index];
        if (stage !== group) continue;
        let cursor = savedCursor ? db.doc(savedCursor) : null;
        while (true) {
          let query = db.collectionGroup(group).orderBy(FieldPath.documentId()).limit(100);
          if (cursor) query = query.startAfter(cursor);
          const page = await query.get();
          if (page.empty) break;
          for (const doc of page.docs) await db.runTransaction(async tx => {
            const current = await tx.get(doc.ref);
            if (!current.exists) return;
            const value = current.data();
            const sender = value.senderUid ?? value.senderId ?? value.fromUid ?? value.from;
            if (group === 'notifications') {
              if (sender === data.uid) tx.delete(doc.ref);
            } else if (doc.id === data.uid || value.uid === data.uid || sender === data.uid) {
              tx.update(doc.ref, { fullName:'Kullanıcı', name:'Kullanıcı', position:'', avatarUrl:'', avatarData:'0' });
            }
          });
          cursor = page.docs.at(-1).ref;
          await job.update({cursor:cursor.path});
        }
        stage = groups[index+1] ?? 'done'; savedCursor = null;
        await job.update({stage, cursor:null});
      }
      await job.update({ status:'completed', completedAt:FieldValue.serverTimestamp() });
      return;
    }
    const id = data.matchId;
    if (typeof id !== 'string' || !id || id.includes('/')) throw new Error('Invalid removal');
    // Retired IDs cannot be recreated by clients. All supported invitation
    // writers read the match, so no new invitations can race this sweep.
    await db.recursiveDelete(db.doc(`matches/${id}`));
    let cursor = data.cursor ? db.doc(data.cursor) : null;
    while (true) {
      let query = db.collectionGroup('notifications').orderBy(FieldPath.documentId()).limit(100);
      if (cursor) query = query.startAfter(cursor);
      const page = await query.get();
      if (page.empty) break;
      const batch = db.batch();
      for (const doc of page.docs) if (doc.get('matchId') === id) batch.delete(doc.ref);
      await batch.commit();
      cursor = page.docs.at(-1).ref;
      await job.update({ cursor: cursor.path });
    }
    await job.update({ status: 'completed', completedAt: FieldValue.serverTimestamp() });
  }
  return { queue, act, restore, cleanupRemoval };
}
module.exports = { createModerationService };
