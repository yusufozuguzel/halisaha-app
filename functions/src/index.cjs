const { initializeApp } = require('firebase-admin/app');
const { getAuth } = require('firebase-admin/auth');
const { getFirestore } = require('firebase-admin/firestore');
const { getStorage } = require('firebase-admin/storage');
const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { onDocumentCreated } = require('firebase-functions/v2/firestore');
const { onObjectFinalized } = require('firebase-functions/v2/storage');
const { defineSecret } = require('firebase-functions/params');
const { createSafetyService } = require('./safety.cjs');
const { createModerationService } = require('./moderation.cjs');
const { identity, exactFields } = require('./policy.cjs');
const { createPrivateLogin, createAuthRest } = require('./private-login.cjs');
const { createLazyPrivateLoginService } = require('./lazy-private-login.cjs');
const { filterImage } = require('./content-filter.cjs');
const { createProfilePhotoUploader } = require('./profile-photo-upload.cjs');
const { createPlacesProxy } = require('./places-proxy.cjs');
const { createUsernameService } = require('./usernames.cjs');

initializeApp();
const deletionEnabled = process.env.DELETION_RULES_VERIFIED === 'true';
const reportsEnabled = process.env.MODERATION_READY === 'true';
const photoModerationEnabled = process.env.PHOTO_MODERATION_READY === 'true' && reportsEnabled;
const placesProxyEnabled = process.env.PLACES_PROXY_READY === 'true';
const usernamesEnabled = process.env.USERNAMES_READY === 'true';
const googleMapsApiKeySecret = placesProxyEnabled ? defineSecret('GOOGLE_MAPS_API_KEY') : null;
const service = createSafetyService({
  db: getFirestore(), auth: getAuth(), bucket: getStorage().bucket(),
  deletionEnabled, reportsEnabled,
});
// App Check stays monitor/off by default. Enable enforcement only after the
// installed mobile clients and staged callable flows have verified tokens.
const options = {
  region: 'europe-west1', maxInstances: 10, timeoutSeconds: 60,
  enforceAppCheck: process.env.ENFORCE_APPCHECK === 'true',
};
const useAuthSecrets = process.env.AUTH_SECRETS_FROM_SECRET_MANAGER === 'true';
const authRateLimitSecret = defineSecret('AUTH_RATE_LIMIT_KEY');
const authWebApiKeySecret = defineSecret('AUTH_WEB_API_KEY');
function callable(handler, callableOptions = options) {
  return onCall(callableOptions, async request => {
    try { return await handler(request); }
    catch (error) {
      if (error instanceof HttpsError) throw error;
      // Never return/log user records, credentials, tokens or raw SDK errors.
      throw new HttpsError('internal', 'İşlem tamamlanamadı. Lütfen tekrar deneyin.');
    }
  });
}
exports.safetyStatus = callable(request => {
  return getSafetyStatus(request);
});
async function getSafetyStatus(request) {
  identity(request);
  exactFields(request.data, []);
  const policy = await getFirestore().doc('_runtimePolicy/safety').get();
  return { deletionEnabled, reportsEnabled, photoModerationEnabled,
    placesProxyEnabled, usernamesEnabled, abuseControlsEnabled: policy.exists && policy.get('enabled') === true };
}
exports.prepareAccountDeletion = callable(service.prepareDeletion);
exports.requestAccountDeletion = callable(service.requestDeletion);
exports.submitContentReport = callable(service.submitReport);
exports.listContentReports = callable(service.listReports);
exports.reviewContentReport = callable(service.reviewReport);
const moderation = createModerationService({ db: getFirestore(), bucket: getStorage().bucket(), enabled: reportsEnabled });
exports.moderationQueue = callable(moderation.queue);
exports.applyModerationAction = callable(moderation.act);
exports.restoreModeratedAccount = callable(moderation.restore);
let uploadVisionClient;
const profilePhotoUploader = createProfilePhotoUploader({
  db: getFirestore(), auth: getAuth(), bucket: getStorage().bucket(),
  visionClient: { safeSearchDetection: request => {
    if (!uploadVisionClient) {
      const vision = require('@google-cloud/vision');
      uploadVisionClient = new vision.ImageAnnotatorClient();
    }
    return uploadVisionClient.safeSearchDetection(request);
  } },
  enabled: photoModerationEnabled,
});
exports.uploadProfilePhoto = callable(profilePhotoUploader, {
  ...options, maxInstances: 5, concurrency: 1,
});
const placesProxy = createPlacesProxy({
  db: getFirestore(), getApiKey: () => googleMapsApiKeySecret?.value() || '', enabled: placesProxyEnabled,
});
exports.placesProxy = callable(placesProxy, placesProxyEnabled
  ? { ...options, secrets: [googleMapsApiKeySecret], timeoutSeconds: 30, memory: '512MiB', maxInstances: 5, concurrency: 4 }
  : options);
const usernames = createUsernameService({ db: getFirestore(), enabled: usernamesEnabled });
exports.claimUsername = callable(usernames.claim);
exports.findUsername = callable(usernames.find);
exports.cleanupModeratedMatch = onDocumentCreated({
  document: '_moderationRemovals/{reportId}', region: 'europe-west1',
  retry: true, maxInstances: 1, concurrency: 1, timeoutSeconds: 540,
}, async event => {
  if (!reportsEnabled) throw new Error('Moderation is not enabled');
  try { await moderation.cleanupRemoval(event.params.reportId); }
  catch (_) { throw new Error('Moderation cleanup incomplete; retry required'); }
});
// SecretParam.value() is only available at runtime after the function's
// secrets have been mounted. Never resolve it during deployment discovery.
const getPrivateLogin = createLazyPrivateLoginService({
  create: ({ rateKey, apiKey }) => createPrivateLogin({
      db: getFirestore(), auth: getAuth(),
      enabled: process.env.PRIVATE_LOGIN_READY === 'true',
      rateKey,
      authRest: createAuthRest({
        apiKey,
        emulatorHost: process.env.FIREBASE_AUTH_EMULATOR_HOST,
      }),
    }),
  getRateKey: () => useAuthSecrets ? authRateLimitSecret.value() : (process.env.AUTH_RATE_LIMIT_KEY || ''),
  getApiKey: () => useAuthSecrets ? authWebApiKeySecret.value() : process.env.AUTH_WEB_API_KEY,
});
const privateLoginOptions = useAuthSecrets
  ? { ...options, secrets: [authRateLimitSecret, authWebApiKeySecret] }
  : options;
exports.verifyUsernamePassword = callable(request => getPrivateLogin().verifyUsernamePassword(request), privateLoginOptions);
exports.resetUsernamePassword = callable(request => getPrivateLogin().resetUsernamePassword(request), privateLoginOptions);
exports.processAccountDeletion = onDocumentCreated({
  document: 'accountDeletionJobs/{uid}', region: 'europe-west1',
  retry: true, maxInstances: 1, concurrency: 1, timeoutSeconds: 540, memory: '512MiB',
}, async event => {
  if (!deletionEnabled) throw new Error('Account deletion is not enabled');
  try { await service.processDeletion(event.params.uid); }
  catch (_) { throw new Error('Account cleanup incomplete; retry required'); }
});
exports.removeLateProfileUpload = onObjectFinalized({
  region:'europe-west1', retry:true, maxInstances:2, timeoutSeconds:60,
}, async event => {
  if (!deletionEnabled && !reportsEnabled) return;
  try { await service.removeLateProfileUpload(event.data); }
  catch (_) { throw new Error('Late profile cleanup incomplete; retry required'); }
});

exports.analyzeImageContent = onObjectFinalized({
  region: 'europe-west1', 
  retry: true, 
  maxInstances: 5, 
  timeoutSeconds: 60,
}, async event => {
  if (!reportsEnabled) return;
  try { await filterImage(event.data); }
  catch (_) { throw new Error('Image analysis incomplete; retry required'); }
});

