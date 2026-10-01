const { initializeApp, deleteApp } = require('firebase-admin/app');
const { getFirestore } = require('firebase-admin/firestore');
const { getAuth } = require('firebase-admin/auth');
const { migrateProfiles } = require('../src/profile-migration.cjs');

async function main() {
  const args = process.argv.slice(2);
  const project = args.find(a => a.startsWith('--project='))?.slice(10);
  if (!project || !/^[a-z][a-z0-9-]+$/.test(project) ||
      args.some(a => !a.startsWith('--project=') && a !== '--apply-local')) {
    throw new Error('Usage: node tool/migrate-profiles.cjs --project=PROJECT [--apply-local]');
  }
  const apply = args.includes('--apply-local');
  if (apply && (project !== 'demo-depar-review' ||
      process.env.FIRESTORE_EMULATOR_HOST !== '127.0.0.1:8088' ||
      process.env.FIREBASE_AUTH_EMULATOR_HOST !== '127.0.0.1:9098')) {
    throw new Error('Writes are restricted to local demo emulators. Production migration is not authorized.');
  }
  const app = initializeApp({ projectId:project });
  try {
    const counts = await migrateProfiles({ db:getFirestore(app), auth:getAuth(app), apply });
    console.log(JSON.stringify({ mode:apply ? 'local-apply' : 'read-only', ...counts }));
  } finally { await deleteApp(app); }
}
main().catch(() => { console.error('Profile migration did not complete; no record details logged.'); process.exitCode = 1; });
