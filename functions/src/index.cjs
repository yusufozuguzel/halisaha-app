const { initializeApp } = require('firebase-admin/app');
const { getAuth } = require('firebase-admin/auth');
const { getFirestore } = require('firebase-admin/firestore');
const { getStorage } = require('firebase-admin/storage');
const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { onDocumentCreated } = require('firebase-functions/v2/firestore');
const { onObjectFinalized } = require('firebase-functions/v2/storage');
const { createSafetyService } = require('./safety.cjs');
const { createModerationService } = require('./moderation.cjs');
const { identity, exactFields } = require('./policy.cjs');
const { createPrivateLogin, createAuthRest } = require('./private-login.cjs');
const { filterImage } = require('./content-filter.cjs');

initializeApp();
const deletionEnabled = process.env.DELETION_RULES_VERIFIED === 'true';
const reportsEnabled = process.env.MODERATION_READY === 'true';
const service = createSafetyService({
  db: getFirestore(), auth: getAuth(), bucket: getStorage().bucket(),
  deletionEnabled, reportsEnabled,
});
const options = { region: 'europe-west1', maxInstances: 10, timeoutSeconds: 60 };
function callable(handler) {
  return onCall(options, async request => {
    try { return await handler(request); }
    catch (error) {
      if (error instanceof HttpsError) throw error;
      // Never return/log user records, credentials, tokens or raw SDK errors.
      throw new HttpsError('internal', 'İşlem tamamlanamadı. Lütfen tekrar deneyin.');
    }
  });
}
exports.safetyStatus = callable(request => {
  identity(request);
  exactFields(request.data, []);
  return { deletionEnabled, reportsEnabled };
});
exports.prepareAccountDeletion = callable(service.prepareDeletion);
exports.requestAccountDeletion = callable(service.requestDeletion);
exports.submitContentReport = callable(service.submitReport);
exports.listContentReports = callable(service.listReports);
exports.reviewContentReport = callable(service.reviewReport);
const moderation = createModerationService({ db: getFirestore(), bucket: getStorage().bucket(), enabled: reportsEnabled });
exports.moderationQueue = callable(moderation.queue);
exports.applyModerationAction = callable(moderation.act);
exports.restoreModeratedAccount = callable(moderation.restore);
exports.cleanupModeratedMatch = onDocumentCreated({
  document: '_moderationRemovals/{reportId}', region: 'europe-west1',
  retry: true, maxInstances: 1, concurrency: 1, timeoutSeconds: 540,
}, async event => {
  if (!reportsEnabled) throw new Error('Moderation is not enabled');
  try { await moderation.cleanupRemoval(event.params.reportId); }
  catch (_) { throw new Error('Moderation cleanup incomplete; retry required'); }
});
const privateLogin = createPrivateLogin({
  db: getFirestore(), auth: getAuth(),
  enabled: process.env.PRIVATE_LOGIN_READY === 'true',
  rateKey: process.env.AUTH_RATE_LIMIT_KEY || '',
  authRest: createAuthRest({
    apiKey: process.env.AUTH_WEB_API_KEY,
    emulatorHost: process.env.FIREBASE_AUTH_EMULATOR_HOST,
  }),
});
exports.verifyUsernamePassword = callable(privateLogin.verifyUsernamePassword);
exports.resetUsernamePassword = callable(privateLogin.resetUsernamePassword);
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

