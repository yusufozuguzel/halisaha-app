const { createHmac } = require('node:crypto');
const { Timestamp } = require('firebase-admin/firestore');
const { HttpsError } = require('firebase-functions/v2/https');
const { exactFields, requireEnabled } = require('./policy.cjs');

const invalidLogin = () => new HttpsError('unauthenticated', 'Kullanıcı adı veya şifre hatalı.');

// Firebase Auth is the sole source of email/password identity. Profile email
// fields, caller-supplied UIDs and provider claims are never trusted.
function createPrivateLogin({ db, auth, authRest, enabled = false, rateKey = '', now = Date.now }) {
  function ready() {
    requireEnabled(enabled && rateKey.length >= 32);
  }
  function identifier(data, fields) {
    exactFields(data, fields);
    const name = data.username;
    if (typeof name !== 'string' || !name.trim() || name.trim().length > 100 || name.includes('@')) {
      throw new HttpsError('invalid-argument', 'Geçerli bir kullanıcı adı girin.');
    }
    return name.trim(); // Preserve existing case-sensitive fullName/name behavior.
  }
  async function throttle(request, name, operation) {
    // Some Functions runtimes supply only the transport address. Do not read
    // caller-controlled forwarded headers; a shared proxy is conservatively
    // one bucket until its trusted forwarding behavior is verified in staging.
    const localDemo = process.env.FUNCTIONS_EMULATOR === 'true'
      && process.env.GCLOUD_PROJECT === 'demo-depar-review'
      && process.env.FIRESTORE_EMULATOR_HOST === '127.0.0.1:8088'
      && process.env.FIREBASE_AUTH_EMULATOR_HOST === '127.0.0.1:9098';
    // The Windows Functions emulator forwards over a named pipe, which has
    // no remoteAddress. All requests share one conservative LOCAL-ONLY bucket.
    const ip = request.rawRequest?.ip || request.rawRequest?.socket?.remoteAddress
      || (localDemo ? 'local-emulator' : null);
    if (typeof ip !== 'string' || !ip) throw new HttpsError('unavailable', 'İşlem tamamlanamadı.');
    const time = now();
    const period = operation === 'reset' ? 3600000 : 900000;
    const window = Math.floor(time / period);
    const limits = operation === 'reset' ? [3, 10] : [10, 40];
    const refs = [`name:${name.toLowerCase()}`, `ip:${ip}`].map(value => db.doc(
      `_loginLimits/${createHmac('sha256', rateKey).update(`${operation}:${window}:${value}`).digest('hex')}`,
    ));
    await db.runTransaction(async tx => {
      const docs = await tx.getAll(...refs);
      if (docs.some((doc, i) => (doc.data()?.count ?? 0) >= limits[i])) {
        throw new HttpsError('resource-exhausted', 'Çok fazla deneme yapıldı. Daha sonra tekrar deneyin.');
      }
      docs.forEach((doc, i) => tx.set(refs[i], {
        count: (doc.data()?.count ?? 0) + 1,
        expiresAt: Timestamp.fromMillis((window + 2) * period),
      }));
    });
  }
  async function account(name) {
    let results = await db.collection('users').where('fullName', '==', name).limit(2).get();
    if (results.empty) results = await db.collection('users').where('name', '==', name).limit(2).get();
    if (results.size !== 1) return null; // Never guess when display names collide.
    const uid = results.docs[0].id;
    if ((await db.doc(`accountDeletionJobs/${uid}`).get()).exists) return null;
    try {
      const user = await auth.getUser(uid);
      if (user.disabled || !user.email || !user.providerData.some(p => p.providerId === 'password')) return null;
      return user;
    } catch (error) {
      if (error.code === 'auth/user-not-found') return null;
      throw error;
    }
  }
  return {
    async verifyUsernamePassword(request) {
      ready();
      const name = identifier(request.data, ['username', 'password']);
      const password = request.data.password;
      if (typeof password !== 'string' || !password || password.length > 4096) throw invalidLogin();
      await throttle(request, name, 'login');
      const user = await account(name);
      if (!user) throw invalidLogin();
      const verified = await authRest('signInWithPassword', {
        email: user.email, password, returnSecureToken: true,
      });
      // In particular, do NOT exchange an MFA pending credential for a custom
      // token. Native email/password sign-in will still perform normal Auth checks.
      if (verified.error || verified.mfaPendingCredential || !verified.idToken || verified.localId !== user.uid) {
        throw invalidLogin();
      }
      if ((await db.doc(`accountDeletionJobs/${user.uid}`).get()).exists) throw invalidLogin();
      // Only a verified password holder receives their own email; no ID/refresh
      // tokens or account metadata are returned, persisted or logged here.
      return { email: user.email };
    },
    async resetUsernamePassword(request) {
      ready();
      const name = identifier(request.data, ['username']);
      await throttle(request, name, 'reset');
      const user = await account(name);
      if (user) {
        const result = await authRest('sendOobCode', { requestType: 'PASSWORD_RESET', email: user.email });
        // Known/unknown/disabled/social/ambiguous names get the same response.
        if (result.error && !['EMAIL_NOT_FOUND', 'USER_DISABLED', 'TOO_MANY_ATTEMPTS_TRY_LATER'].includes(result.error.message)) {
          throw new HttpsError('unavailable', 'İşlem tamamlanamadı.');
        }
      }
      return { accepted: true };
    },
  };
}

function createAuthRest({ apiKey, emulatorHost, fetchImpl = fetch }) {
  const emulator = emulatorHost === '127.0.0.1:9098';
  if (emulatorHost && !emulator) throw new Error('Unsupported Auth emulator address');
  return async (operation, data) => {
    if (!['signInWithPassword', 'sendOobCode'].includes(operation) || !apiKey) {
      throw new HttpsError('unavailable', 'Giriş hizmeti hazır değil.');
    }
    const base = emulator ? `http://${emulatorHost}/identitytoolkit.googleapis.com` : 'https://identitytoolkit.googleapis.com';
    try {
      const response = await fetchImpl(`${base}/v1/accounts:${operation}?key=${encodeURIComponent(apiKey)}`, {
        method: 'POST', headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(data), signal: AbortSignal.timeout(15000), redirect: 'error',
      });
      const result = await response.json();
      if ((!response.ok && !result.error) || !result || typeof result !== 'object') throw new Error('Invalid Auth response');
      return result;
    } catch (_) {
      throw new HttpsError('unavailable', 'Giriş hizmetine ulaşılamadı.');
    }
  };
}

module.exports = { createPrivateLogin, createAuthRest };
