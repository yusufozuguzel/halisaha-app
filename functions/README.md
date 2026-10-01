# DEPAR safety backend — local implementation

Not deployed. The user supplied Firestore and Storage rules; their normalized unsafe baselines are preserved only under `security-tests/fixtures/`. Complete local candidates now exist for both services. Actual console state, bucket contents, other writers and the full production schema still need verification. Both `DELETION_RULES_VERIFIED` and `MODERATION_READY` remain false. Do not enable them merely because isolated tests pass. Storage policy and rollout: [rules/STORAGE.md](rules/STORAGE.md).

## Integration requirements

- Username login/reset now have a separate local implementation and rollout:
  [PRIVATE_LOGIN.md](PRIVATE_LOGIN.md). PRIVATE_LOGIN_READY defaults false; the
  updated app requires those endpoints for username input, while email sign-in
  still uses Firebase Auth directly. Profile migration is not yet run live.

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

`MODERATION_READY` still requires real staffing, response procedures and verified deployment of the complete rules/backend. The user provided `depardestek@gmail.com`; delivery and inbox ownership/response duties remain unverified. Two-sided interaction rules and own-block UI filtering are locally implemented; they do not make profiles or matches private. No production claim or credentials were fabricated.

## Local verification

Run `npm ci --ignore-scripts` and `npm test` here. In `../security-tests`, run `npm ci --ignore-scripts`, `npm test`, and `npm run test:backend`. These use demo projects only; tests reject non-local emulator hosts. The backend fault tests mock Storage; the separate `functions.test.cjs` exercises real local Functions/Auth/Firestore/Storage emulators and the actual trigger.

`npm run test:combined-rules` includes account-isolation, inbound-reference and retired-ID tests. `npm run test:deletion-integration` runs backend faults/concurrent workers and the real Storage-to-Firestore guard check sequentially in local emulators. The Storage emulator must use the same demo project for its cross-service Firestore lookups.

For that end-to-end test, in a temporary PowerShell process in `security-tests`, set `DELETION_RULES_VERIFIED=true` and `MODERATION_READY=true` as process environment variables, then run:

```powershell
& .\node_modules\.bin\firebase.cmd emulators:exec --config functions.firebase.json --only functions,firestore,auth,storage --project demo-depar-review 'node --test functions.test.cjs'
```

These flags are exclusively for the local demo run. Do not copy them into production configuration. Local verification used Node 24; the configured Node 22 deployment runtime still needs staging validation. Native iOS authentication/token revocation and real device flows are separate checks.
