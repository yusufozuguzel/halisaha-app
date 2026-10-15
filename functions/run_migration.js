const { initializeApp } = require('firebase-admin/app');
const { getAuth } = require('firebase-admin/auth');
const { getFirestore } = require('firebase-admin/firestore');
const { migrateProfiles } = require('./src/profile-migration.cjs');

function parseArgs(args) {
  const options = { apply: false, project: null, confirmProject: null };
  for (let i = 0; i < args.length; i++) {
    const arg = args[i];
    if (arg === '--apply') options.apply = true;
    else if (arg === '--project' || arg === '--confirm-project') {
      const value = args[++i];
      if (!value || value.startsWith('--')) throw new Error(`${arg} requires a value`);
      if (arg === '--project') options.project = value;
      else options.confirmProject = value;
    } else {
      throw new Error(`Unknown argument: ${arg}`);
    }
  }

  if (!options.project || !/^[a-z][a-z0-9-]{4,28}[a-z0-9]$/.test(options.project)) {
    throw new Error('--project must be an exact Firebase project ID');
  }
  if (options.apply && options.confirmProject !== options.project) {
    throw new Error('Apply requires --confirm-project with the exact same project ID');
  }
  if (!options.apply && options.confirmProject) {
    throw new Error('--confirm-project is only valid together with --apply');
  }
  return options;
}

async function runMigration({ args = process.argv.slice(2), migrate = migrateProfiles, log = console.log } = {}) {
  const options = parseArgs(args);
  const app = initializeApp({ projectId: options.project });
  try {
    const db = getFirestore(app);
    const auth = getAuth(app);
    const counts = await migrate({ db, auth, apply: options.apply });
    log(options.apply ? 'Apply Results:' : 'Dry Run Results:', counts);
    if (!options.apply) {
      log(`No writes performed. To apply, rerun with --apply --project ${options.project} --confirm-project ${options.project}`);
    }
    return counts;
  } finally {
    await app.delete();
  }
}

if (require.main === module) {
  runMigration().catch(error => {
    const parseError = /^(--|Unknown argument|Apply requires)/.test(error.message);
    console.error(parseError ? error.message : 'Profile migration did not complete; no record details logged.');
    process.exitCode = 1;
  });
}

module.exports = { parseArgs, runMigration };
