const { initializeApp } = require('firebase-admin/app');
const { getAuth } = require('firebase-admin/auth');
const { getFirestore } = require('firebase-admin/firestore');
const { migrateProfiles } = require('./src/profile-migration.cjs');

// Initialize Firebase Admin
initializeApp();

async function run() {
  const db = getFirestore();
  const auth = getAuth();
  
  console.log("Starting profile migration (Dry Run)...");
  let counts = await migrateProfiles({ db, auth, apply: false });
  console.log("Dry Run Results:", counts);
  
  if (counts.ready > 0) {
    console.log("Applying migration...");
    counts = await migrateProfiles({ db, auth, apply: true });
    console.log("Apply Results:", counts);
  } else {
    console.log("No profiles need migration.");
  }
}

run().catch(console.error);
