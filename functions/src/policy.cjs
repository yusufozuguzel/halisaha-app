const { HttpsError } = require('firebase-functions/v2/https');

function identity(request, { recent = false, now = Date.now() } = {}) {
  const uid = request.auth?.uid;
  if (typeof uid !== 'string' || !uid || uid.length > 128 || uid.includes('/')) {
    throw new HttpsError('unauthenticated', 'Oturum açmanız gerekiyor.');
  }
  if (recent) {
    const time = request.auth.token?.auth_time;
    const age = now / 1000 - time;
    if (!Number.isFinite(time) || age < -60 || age > 300) {
      throw new HttpsError('failed-precondition', 'Lütfen yeniden giriş yapın.');
    }
  }
  return uid;
}

function exactFields(data, fields) {
  if (!data || Array.isArray(data) || typeof data !== 'object' ||
      Object.keys(data).length !== fields.length || fields.some(k => !(k in data))) {
    throw new HttpsError('invalid-argument', 'Geçersiz istek.');
  }
}

function requireEnabled(enabled) {
  if (!enabled) throw new HttpsError('unavailable', 'Hizmet henüz kullanıma hazır değil.');
}

const referenceFields = ['uid', 'from', 'fromUid', 'senderUid', 'senderId', 'receiverId', 'userId', 'targetUid'];
function referencesUser(data, uid) {
  return referenceFields.some(field => data[field] === uid);
}

function matchCleanup(data, uid) {
  const patch = {};
  for (const key of ['currentPlayers', 'invitedPlayers']) {
    if (Array.isArray(data[key]) && data[key].includes(uid)) {
      patch[key] = data[key].filter(value => value !== uid);
    }
  }
  for (const key of ['positions', 'pendingPositions']) {
    if (data[key] && typeof data[key] === 'object' && !Array.isArray(data[key])) {
      const entries = Object.entries(data[key]);
      const kept = entries.filter(([, value]) => value !== uid && value?.uid !== uid);
      if (kept.length !== entries.length) patch[key] = Object.fromEntries(kept);
    }
  }
  return patch;
}

module.exports = { identity, exactFields, requireEnabled, referencesUser, matchCleanup };
