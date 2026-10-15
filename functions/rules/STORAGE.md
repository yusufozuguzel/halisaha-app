# Storage policy — moderated-upload candidate

The user supplied the Storage rules after the Firestore rules. The normalized
baseline is `security-tests/fixtures/user-provided.storage.rules`: every signed-in
user can read, replace and delete any object. It is retained only as an unsafe
test fixture. The actual production rules were read in the earlier authorized
rollout and were already hardened. The changes described below are local only;
the user has stopped publication and deployment work.

`storage.candidate.rules` is a complete replacement for that broad grant.
Generate it with `node functions/rules/assemble.cjs`; edit the two Storage
fragments rather than the generated file. Both `firebase.emulator.json` and
`firebase.json` reference it, but wiring a filename is not a deployment.

## Supported application paths

The two Flutter upload sites (profile setup and profile editing) and both cleanup
workers use exactly `profile_images/{uid}.jpg`. No other Storage paths were found
in this repository. The new policy permits authenticated SDK get requests for
profile photos, denies listing, and denies all client create/update requests.
Only the server `uploadProfilePhoto` callable can publish bytes after scanning.
Owner deletion remains limited to the authenticated UID plus `.jpg`.
Unknown/nested paths are
denied, including reads of objects outside this profile path. Existing bucket
contents and other apps/Admin writers still need an inventory before rollout.

The server checks 1–5,242,880 decoded bytes, canonical base64, declared MIME
`image/jpeg`, `image/png` or `image/webp`, matching image signatures and a complete
Vision SafeSearch result before any object write. Delete is separate; owners
can remove old incorrectly typed files. Owner deletion also requires no
`accountDeletionJobs/{uid}` and no `_moderationAccounts/{uid}`. Moderator claims
do not grant direct Storage write access. Trusted Admin cleanup bypasses rules.

Both Flutter upload sites share `uploadProfilePhoto`. It checks file size and
JPEG/PNG/WebP signatures, binds authentication to the requested owner and uses
the moderated callable when `safetyStatus.photoModerationEnabled` is true.
False rejects safely; only a missing field identifies the earlier backend and
preserves its legacy uploader during transition. Network, rejection and scan
errors never fall through to direct Storage. The fixed object name is retained.
Unsupported formats such as HEIC,
GIF or SVG produce a clear error if the platform picker has not converted them.
Cancellation preserves the previous avatar. New errors omit raw SDK details.

MIME alone cannot prove safe contents. A modified client cannot bypass the new
policy with ownership metadata, a download token or a moderator claim. The
callable derives UID from verified authentication, rate-limits per account,
rechecks deletion/moderation barriers after scanning and saves with the observed
Storage generation as a precondition. Failed scans leave the previous object
untouched. The rate record has TTL expiry and account-deletion cleanup.

## Before deployment

- Replace the old blanket grant entirely; an overlapping broad allow would
  bypass the new restrictions. Preserve the source snapshot for rollback review,
  not as a recommended rollback policy.
- This candidate and the matching callable/client must be considered together.
  Deploying only the candidate denies the earlier direct uploader. The new
  callable requires both `PHOTO_MODERATION_READY=true` and moderation readiness.
  These are future activation prerequisites; no activation was performed here.
- Verify the bucket/project/database location and all real object paths. Review
  existing files above 5 MB or with legacy MIME, and test the old/new Flutter
  upload clients in a demo/staging environment. Old direct-upload clients cannot
  publish photos under this candidate.
- Enable/verify Storage Rules access to the **default** Firestore database using
  the Firebase console/CLI service permission flow. This guard consumes both
  allowed cross-service document accesses. Test deployed rules and IAM together.
  See [Firebase conditions](https://firebase.google.com/docs/storage/security/rules-conditions)
  and [rule syntax and overlapping grants](https://firebase.google.com/docs/storage/security/core-syntax).
- Existing `getDownloadURL()` token URLs are shareable. Authenticated SDK reads
  do not make an already shared token URL private. Review token rotation, cached
  copies, object versioning and soft-delete retention for removal/privacy needs.
  The current app renders these URLs; this change does not silently replace that
  architecture with authenticated-only byte downloads.
- Verify both cleanup triggers, their exact bucket/region, retries and late
  uploads in staging. The earlier rollout's deletion/moderation flags remain
  unchanged; the new photo-upload function, flag and stricter candidate have
  not been deployed.

## Local verification

Run `npm run test:storage-rules` in `security-tests`. It starts only local
Firestore/Storage demo emulators. The baseline test proves the unsafe policy;
the candidate tests cover ownership, peer reads, anonymous access, listing,
unknown paths, owner-upload denial, metadata/token bypass attempts, stale-token
deletion/restriction barriers, restoration and legacy deletion. Backend unit
tests cover size/MIME, failed/incomplete/unsafe scans, account barriers and
Storage-generation races.

`test/profile_photo_upload_test.dart` checks the client signature/size policy.
The earlier `storage-guards.test.cjs` remains a focused helper fixture; it should
not be confused with these complete candidate-rule tests.
