# DEPAR safety backend

Production update verified on 12 October 2026 for `halisaha-app-d9ea1`: all 15 functions deployed; deletion, moderation and private-login readiness enabled. Actual Firestore and Storage policies were inspected, and the new social visibility policy was deployed. Unsafe fixtures remain test-only. Real-device deletion and provider flows still need validation. Current rollout record and backup details: [release runbook](../docs/release-runbook.md). Storage policy: [rules/STORAGE.md](rules/STORAGE.md).

## Integration requirements

- Username login/reset and the optional unique-handle claim flow are described
  in [PRIVATE_LOGIN.md](PRIVATE_LOGIN.md). PRIVATE_LOGIN_READY and
  USERNAMES_READY are independent gates. The unique-handle code and the other
  optional safety controls described below are local candidate changes; they
  have not been deployed or activated in production.

- Node 22 deployment target; callable endpoints and the Flutter adapter use `europe-west1`. Verify the actual project, database location, bucket and existing functions before deployment. `firebase.json` only registers this local codebase.
- The assembled Firestore and Storage candidates now cover known application paths. Run `npm run test:combined-rules` and `npm run test:storage-rules`. They are local candidates, not deployed or production-approved. Follow `rules/README.md` and `rules/STORAGE.md` for generation and rollout. A separate deny cannot override overlapping broad allows. The older isolated fixtures under `security-tests` must never replace production rules.
- Deletion is now account-scoped: `accountDeletionJobs/{uid}` blocks that actor's writes and new inbound relationships. Unrelated profiles, matches, social operations and reports continue. `_safetyLocks/accountDeletion` is no longer created/read by active guards. Other Admin SDK writers must enforce the same per-account and retired-match barriers; rules do not constrain Admin writes.
- Validate cleanup against the complete production schema and all storage paths. Implemented: owned/shared matches, blocked users, friends/follow requests/followers/following/notifications including orphan subcollections, reports, user subtree and the exact `profile_images/{uid}.jpg` object including versions. Other paths, external backups and third-party data require a separate inventory.
- Coordinate the eventual rollout: do not switch from global to account guards while an older worker using stale-snapshot cleanup is still running. Keep deletion readiness off until the new functions, complete Firestore/Storage rules and Admin writers are verified together. No production transition or cleanup of old lock documents was performed here.

## Deletion lifecycle and recovery

The client reauthenticates, checks backend readiness, revokes Apple authorization when applicable, then requests deletion. The server derives UID from verified authentication and requires authentication within five minutes. Clients cannot select a UID. Acceptance means queued, not completed; the app logs out and says so.

A transaction creates the job, which is also the account's write barrier. Different accounts can queue deletion independently; duplicate requests for one UID reuse the same job. The retryable Firestore trigger stores stage/page cursors. Auth is deleted only after Firestore/Storage cleanup. Storage errors other than 404 retain that account and job, without blocking unrelated clients or deletion jobs. A ten-minute per-job lease prevents duplicate workers and exceeds the nine-minute function timeout. The trigger remains configured with maxInstances:1/concurrency:1 for bounded load; it does not globally lock user writes. Failure releases the worker lease but preserves the job and cursor. Completion marks the job; its tombstone continues to reject stale-token writes.

Shared-match and report cleanup re-reads current documents inside transactions; it does not overwrite a newer roster from a stale scan snapshot. Block-list additions are limited to one active, existing target per update, while removals remain possible. This stops a client from restoring the UID after the cleanup scan has passed. Profile creation cannot seed a block list. Social and invite rules check both endpoints; matches owned by a deleting account are frozen until removed. Server report creation/review also checks the reporter, reviewer and target/owner as applicable.

Before removing an owned match, the worker writes `_retiredMatches/{matchId}` (timestamp only) and its job-local cleanup reference. Rules prevent creating a new match with that ID, so delayed notification/report cleanup cannot affect a replacement match. Clients cannot read/write retired markers. These markers and account jobs need a retention policy; do not expire them while stale writes or cleanup references remain possible.

`removeLateProfileUpload` is a retryable Storage finalized trigger: if a profile photo arrives for an account with a pending/completed deletion job or moderation restriction, it deletes that exact object generation in the configured bucket. It derives UID from the fixed `profile_images/{uid}.jpg` path, never uploaded metadata. Unrelated names, buckets and unrestricted active accounts are untouched. This provides eventual cleanup for an upload that finishes after the worker's file listing; it is not a cross-service atomic deletion guarantee. Verify actual bucket/trigger region compatibility, delivery/retry behavior, versioning/soft-delete retention and cross-service rule permissions before enabling. Full candidate Storage rules are now tested separately from the earlier minimal helper fixture; see `rules/STORAGE.md`.

Before production use, configure monitoring, an owner and response procedure for pending/processing jobs and both Firestore/Storage trigger failures. Verify the platform retry retention window. If retries expire, a trusted operator must arrange a verified re-execution of the existing job/event; a repeated client request does not create a new trigger. Never remove the account barrier or mark completion to hide a failure. Pause any Admin writer that does not enforce the account/target barriers. Keep sensitive records/tokens out of logs.

Completed jobs retain UID, status and timestamps to prevent stale-token writes/replays. Their retention and eventual removal require an explicit product policy coordinated with token expiry and account recreation; no automatic expiry is supplied. Do not claim every identifier is immediately erased.

## Reporting and moderation

Only authenticated callable requests create reports. The server validates targets and reason enums, derives author/time/status, deduplicates by SHA-256 of author/type/target/content-version and rate-limits new reports to one per minute. Changed content can be reported again after an earlier review; retrying the same version remains idempotent. Direct client access to internal collections must be denied by the merged rules.

The settings panel exposes review to accounts with a server-issued `moderator: true` custom claim; the backend independently verifies the claim and recent authentication. Only a trusted administrator may assign it. The queue is paginated. Moderators can remove a match, restrict an account's writes, redact profile text/photo, and restore a restriction. Actions check the reviewed content version and execute on the server. Removal jobs retry and checkpoint cleanup; the UI cannot mark an unapplied action resolved. Details and operational limits: [MODERATION.md](MODERATION.md).

The owner confirmed `destekdepar@gmail.com` and responsibility for the inbox and moderation. With explicit consent, their matching application account received the moderator claim, and it was read back successfully. `MODERATION_READY` is enabled in production. Response procedures and actual inbox delivery remain operator checks. Two-sided interaction rules and own-block UI filtering do not make profiles or matches private.

Profile-image analysis reads the exact Storage generation delivered by the event.
Vision API errors and incomplete responses are thrown so the configured
retryable trigger retries; they are never reported as a clean result. Unsafe
deletes use an `ifGenerationMatch` precondition, and the profile URL is cleared
only if its download token still matches that deleted generation. A superseded
event cannot delete or hide a newer upload. Storage currently permits only
`profile_images/{uid}.jpg`, so there is no `match_images` analysis branch.

`uploadProfilePhoto` is the staged client callable for the `PHOTO_MODERATION_READY`
capability. It derives the UID from callable auth, validates the exact payload,
base64, image signature, MIME and 5 MB limit, checks Auth/deletion/restriction
state before and after Vision, rate-limits per UID with expiring throttle state
(Firestore TTL plus account-deletion cleanup), then writes only the canonical
`profile_images/{uid}.jpg` object with a generation-match precondition. It returns
the Firebase download URL only after a safe scan and successful write; it does
not write any profile document fields. Vision errors, incomplete annotations,
and unsafe results leave an existing object untouched. The client commits the
returned URL with its normal profile update. The readiness flag defaults off.
New clients use the legacy direct Storage path only when an older server omits
the capability field; a false flag or callable failure never falls back. That
older-server compatibility path remains post-upload moderated, so it retains
the visibility gap described above. The existing finalized trigger also remains
a retryable safety net for direct/older uploads.

## Migration, indexes, and optional enforcement

`node functions/run_migration.js --project PROJECT_ID` now targets the named
project and performs a read-only dry run. Writes require both
`--apply --project PROJECT_ID --confirm-project PROJECT_ID`; the two project IDs
must match exactly. Review the aggregate dry-run counts first. A consistent
local document backups, 21 conditional profile updates and index deployment
were completed in production; see the runbook for scope and remaining records.

`rules/firestore.indexes.candidate.json` includes the current profile-search,
upcoming/current-player match, discovery/status, created-by match, and pending
  notification composites. It also declares `_loginLimits.expiresAt`,
  `_profilePhotoLimits.expiresAt` and nested `windows.expiresAt` TTL
field. Verify these against the existing production index inventory before
merging/deploying; TTL cleanup is asynchronous and does not happen in emulator
tests.

- `PLACES_PROXY_READY=true` enables the authenticated `placesProxy` callable
  and binds `GOOGLE_MAPS_API_KEY` only to that function. It proxies bounded
  legacy Places search/details/photo and fixed Static Maps requests, and returns
  data/bytes without exposing the key or upstream URL. Keep the flag false
  until the intended restricted Maps key, billing, API access and staged client
  behavior are verified. The local candidate did not create or set a key.
- `USERNAMES_READY=true` enables authenticated `claimUsername` and
  `findUsername`. Claims are lowercase ASCII handles, unique, and immutable;
  the server maps `_usernames/{handle}` to a UID and stores the handle on the
  v2 profile. The candidate client rules forbid direct creation/change. Account
  deletion releases an owned claim. Claimed handles take priority for
  username/password login; without a claim, exact `fullName` and legacy `name`
  results are unioned and only one unambiguous Auth account can resolve. Existing
  display names and email sign-in semantics remain intact.
- The candidate `abuseControlsEnabled` capability comes from the server-owned
  `_runtimePolicy/safety.enabled` document, defaulting off when absent. When
  enabled, the candidate rules require verified email for match creation,
  follow requests and outbound invites, with same-batch per-UID cooldown records
  for match creation (60 seconds) and follow requests (15 seconds). Incoming
  acceptance/removal stays available. This does not rate-limit every standalone
  match invitation/notification. Clients, functions, rules and this policy must
  be staged and activated together; this repository change neither writes the
  policy document nor updates production.
- Public text screening adds a small exact-token server/rules denylist for
  obvious profanity. It complements the client filter; it is not comprehensive
  language moderation and can be revised without changing the safety model.

Callable App Check enforcement can be enabled with
`ENFORCE_APPCHECK=true`; the default remains false. Enable it only after app
attestation providers and staging callables are confirmed. Private-login
secrets can optionally bind from Secret Manager with
`AUTH_SECRETS_FROM_SECRET_MANAGER=true`; the default uses existing environment
configuration. This code does not create or set secret values, and
`PRIVATE_LOGIN_READY` remains an independent off-by-default feature gate.

The local legacy-avatar utility handles only `avatarType: "base64"` JPEGs. It
is pinned to project `halisaha-app-d9ea1`, requires an explicit bucket, and
defaults to aggregate-only dry run. Set `FIREBASE_TOOLS_ROOT` to the installed
Firebase CLI 15.33.0 package directory; the utility bridges its existing login
to Google OAuth in memory and does not print tokens or create a credential
file. Firestore REST and Identity Platform APIs use that OAuth client; the
Google Cloud Storage client accepts it directly. The Firebase CLI may update
its own normal credential cache when it refreshes a token. Add `--scan-vision` to the dry run for read-only SafeSearch
checks, which may incur Vision API charges. Apply requires `--apply` plus an
exact matching `--confirm-project`; it scans first, skips orphan profiles and
existing destination objects, uploads with `ifGenerationMatch: 0`, and updates
the profile under its snapshot `updateTime` precondition. With explicit consent
for Vision processing, three legacy photos were migrated in production and
their byte integrity and URL association verified. The orphan photo was skipped.

## Local verification

Run `npm ci --ignore-scripts` and `npm test` here. In `../security-tests`, run `npm ci --ignore-scripts`, `npm test`, and `npm run test:backend`. These use demo projects only; tests reject non-local emulator hosts. The backend fault tests mock Storage; the separate `functions.test.cjs` exercises real local Functions/Auth/Firestore/Storage emulators and the actual trigger.

`npm run test:combined-rules` includes account-isolation, inbound-reference and retired-ID tests. `npm run test:deletion-integration` runs backend faults/concurrent workers and the real Storage-to-Firestore guard check sequentially in local emulators. The Storage emulator must use the same demo project for its cross-service Firestore lookups.

For that end-to-end test, in a temporary PowerShell process in `security-tests`, set `DELETION_RULES_VERIFIED=true` and `MODERATION_READY=true` as process environment variables, then run:

```powershell
& .\node_modules\.bin\firebase.cmd emulators:exec --config functions.firebase.json --only functions,firestore,auth,storage --project demo-depar-review 'node --test functions.test.cjs'
```

These flags are exclusively for the local demo run. Do not copy them into production configuration. Local verification used Node 24; the configured Node 22 deployment runtime still needs staging validation. Native iOS authentication/token revocation and real device flows are separate checks.
