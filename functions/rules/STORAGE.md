# Storage policy — local candidate, not deployed

The user supplied the Storage rules after the Firestore rules. The normalized
baseline is `security-tests/fixtures/user-provided.storage.rules`: every signed-in
user can read, replace and delete any object. It is retained only as an unsafe
test fixture. No console configuration or production bucket was accessed.

`storage.candidate.rules` is a complete replacement for that broad grant.
Generate it with `node functions/rules/assemble.cjs`; edit the two Storage
fragments rather than the generated file. It is wired only into
`firebase.emulator.json`, not production `firebase.json`.

## Supported application paths

The two Flutter upload sites (profile setup and profile editing) and both cleanup
workers use exactly `profile_images/{uid}.jpg`. No other Storage paths were found
in this repository. The new policy permits authenticated SDK get requests for
profile photos, denies listing, and allows create/update/delete only when the
object name equals the authenticated UID plus `.jpg`. Unknown/nested paths are
denied, including reads of objects outside this profile path. Existing bucket
contents and other apps/Admin writers still need an inventory before rollout.

Create/update require 1–5,242,880 bytes and declared MIME `image/jpeg`, `image/png`
or `image/webp`. Delete is separate because it has no incoming resource; owners
can remove old incorrectly typed files. Every client write also requires no
`accountDeletionJobs/{uid}` and no `_moderationAccounts/{uid}`. Moderator claims
do not grant direct Storage write access. Trusted Admin cleanup bypasses rules.

Both Flutter upload sites share `uploadProfilePhoto`. It checks file size and
JPEG/PNG/WebP signatures, uploads the same inspected bytes with explicit MIME,
and preserves the existing fixed object name. Unsupported formats such as HEIC,
GIF or SVG produce a clear error if the platform picker has not converted them.
Cancellation preserves the previous avatar. New errors omit raw SDK details.

MIME is client-provided metadata, not server-side image decoding or malware/
content classification. A modified client can label arbitrary bytes as an image;
the rules still enforce ownership, size and account barriers. The local header
check is user feedback, not a replacement for server validation. Any stricter
content scanning/transcoding would require a separate server upload workflow.

## Before deployment

- Replace the old blanket grant entirely; an overlapping broad allow would
  bypass the new restrictions. Preserve the source snapshot for rollback review,
  not as a recommended rollback policy.
- Verify the bucket/project/database location and all real object paths. Review
  existing files above 5 MB or with legacy MIME, and test the old/new Flutter
  upload clients in staging. The updated app supports explicit MIME; old clients
  that sent `application/octet-stream` can fail the stricter policy.
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
  uploads in staging. Restriction/deletion flags remain false until the complete
  Firestore/Storage/backend rollout is verified. No production feature flag,
  role or IAM permission was enabled here.

## Local verification

Run `npm run test:storage-rules` in `security-tests`. It starts only local
Firestore/Storage demo emulators. The baseline test proves the unsafe policy;
the candidate tests cover ownership, peer reads, anonymous access, listing,
unknown paths, MIME/size boundaries, metadata updates, stale-token deletion/
restriction barriers, restoration and legacy deletion. Fake metadata or
moderator claims cannot impersonate another owner.

`test/profile_photo_upload_test.dart` checks the client signature/size policy.
The earlier `storage-guards.test.cjs` remains a focused helper fixture; it should
not be confused with these complete candidate-rule tests.
