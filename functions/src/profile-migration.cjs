const { FieldPath, FieldValue } = require('firebase-admin/firestore');

const publicFields = new Set(['uid','profileVersion','name','fullName','createdAt',
  'position','preferredFoot','city','isProfileComplete','avatarUrl','avatarType','avatarData','blockedUsers']);

function profileMigrationIssue(data, uid) {
  if (Object.keys(data).some(key => key !== 'email' && !publicFields.has(key))) return 'unknownFields';
  if (data.uid !== undefined && data.uid !== uid) return 'invalidShape';
  for (const [key, max] of Object.entries({ name:100, fullName:100, city:100, position:40, avatarUrl:2048 })) {
    if (key in data && (typeof data[key] !== 'string' || data[key].length > max)) return 'invalidShape';
  }
  if ('preferredFoot' in data && !['', 'Sağ', 'Sol', 'İki Ayak'].includes(data.preferredFoot) ||
      'avatarType' in data && !['', 'icon'].includes(data.avatarType) ||
      'avatarData' in data && !['0','1','2','3'].includes(data.avatarData) ||
      'isProfileComplete' in data && typeof data.isProfileComplete !== 'boolean' ||
      'blockedUsers' in data && (!Array.isArray(data.blockedUsers) || data.blockedUsers.length > 500 ||
        data.blockedUsers.some(uid => typeof uid !== 'string')) ||
      'createdAt' in data && typeof data.createdAt?.toMillis !== 'function') return 'invalidShape';
  return null;
}

// Does not duplicate email into another Firestore document: Firebase Auth
// already owns it. Dry run returns only aggregate counts, never profile data.
async function migrateProfiles({ db, auth, apply = false, pageSize = 100 }) {
  const counts = { scanned:0, ready:0, unchanged:0, migrated:0, unknownFields:0, invalidShape:0, missingAuth:0, changedDuringRun:0 };
  let cursor;
  while (true) {
    let query = db.collection('users').orderBy(FieldPath.documentId()).limit(pageSize);
    if (cursor) query = query.startAfter(cursor);
    const page = await query.get();
    if (page.empty) break;
    for (const doc of page.docs) {
      counts.scanned++;
      const data = doc.data();
      const issue = profileMigrationIssue(data, doc.id);
      if (issue) { counts[issue]++; continue; }
      try { await auth.getUser(doc.id); }
      catch (error) {
        if (error.code !== 'auth/user-not-found') throw error;
        counts.missingAuth++; continue;
      }
      if (data.profileVersion === 2 && !('email' in data)) { counts.unchanged++; continue; }
      counts.ready++;
      if (apply) {
        // Abort a stale per-document update; never overwrite an intervening edit.
        try {
          await doc.ref.update({ email: FieldValue.delete(), profileVersion:2 }, { lastUpdateTime:doc.updateTime });
          counts.migrated++;
        } catch (error) {
          if (![5,9].includes(error.code)) throw error;
          counts.changedDuringRun++;
        }
      }
    }
    cursor = page.docs.at(-1);
  }
  return counts;
}

module.exports = { migrateProfiles, profileMigrationIssue };
