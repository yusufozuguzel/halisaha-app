# Private username login

Production status, 12 October 2026: both endpoints deployed to
`halisaha-app-d9ea1`, readiness enabled and secrets bound through Secret Manager.
A synthetic unknown-name request returned HTTP 401 / UNAUTHENTICATED with the
expected generic login error. Successful real-device login, reset delivery and
provider flows remain separate validation steps. See [release runbook](../docs/release-runbook.md).

The Flutter client no longer queries Firestore before login/reset. Email input
still uses native Firebase Auth directly. Username input calls
`verifyUsernamePassword` in europe-west1. The server resolves a unique profile
UID (fullName, then legacy name only if no fullName matches), obtains the email
from **Firebase Auth**, and verifies the exact password using Firebase's
`accounts:signInWithPassword` REST endpoint. Only after successful verification
does it return that user's email for native password sign-in. No custom token
is minted; MFA challenges cannot be converted into a session by this endpoint.
MFA users must use their email/native MFA flow; this app has no new MFA UI.

This deliberately sends a username user's password over TLS to our backend and
then to Firebase Auth. Passwords, Auth responses, tokens, email addresses and
request bodies must never be logged, persisted or included in diagnostics.
The native sign-in verifies the password a second time, preserving the normal
password provider and subsequent reauthentication. Do not add a public
username-to-email lookup or an anonymous Firestore fallback.

`resetUsernamePassword` invokes Firebase's PASSWORD_RESET email operation on the
server. Known, unknown, ambiguous, disabled and passwordless names receive the
same `{accepted:true}` payload. No email address or reset link is returned.
This is response-content protection, not a claim of constant-time execution.
Firebase's email enumeration protection was read back as enabled in the
production Identity Toolkit configuration on 12 October 2026; native email
login/reset remains subject to that setting.

The optional unique-handle service uses `USERNAMES_READY`, which defaults off.
An authenticated profile owner may claim one lowercase ASCII handle (3–30
letters, digits or underscores); claims are unique and cannot be changed by a
client. `findUsername` returns only the claimed UID and public display name.
Claimed handles take priority during username/password resolution. Without a
claim, the server unions exact `fullName` and legacy `name` matches and proceeds
only when one profile is unambiguous. Existing display names and email sign-in
semantics remain unchanged. The callable, client UI and complete rules candidate
must be staged together before enabling this capability. This local optional
flow has not been deployed or activated in production.

## Rate limits and configuration

Both unauthenticated callables are disabled unless PRIVATE_LOGIN_READY is true
and AUTH_RATE_LIMIT_KEY is at least 32 characters. Configure AUTH_WEB_API_KEY
for the **same** Firebase project before enabling. It is a Firebase web API key,
not a service account credential. The rate-key must be a random server-only
secret; do not put it in Flutter assets or the root .env. Secret values are
absent from source control and this document.

For Secret Manager, first create the `AUTH_RATE_LIMIT_KEY` and
`AUTH_WEB_API_KEY` secrets in the intended project, then set
`AUTH_SECRETS_FROM_SECRET_MANAGER=true` in the Functions environment. Only the
two private-login callables bind those secrets. The default remains false and
does not bind or create any secrets. `PRIVATE_LOGIN_READY` remains a separate
off-by-default gate. Production secrets were created through the authenticated
Firebase CLI; their values were not printed or added to the repository.

Transactions enforce fixed-window username and IP buckets across function
instances. Login allows 10/name-and-IP and 40/IP per 15 minutes; reset allows 3/name
and 10/IP per hour. A shared IP can hit its limit. Window boundaries permit a
burst across two windows. Distributed attacks, endpoint cost controls and
App Check enforcement require staging/operations review; this is not a DDoS
solution. Verify the trusted client-IP path behind the production proxy before
enabling; never trust a caller's forwarded header without a verified proxy.

`_loginLimits` stores only HMAC bucket IDs, counts and expiresAt. The candidate
Firestore index file declares TTL on its expiresAt field and on nested `windows`
rate-limit records used by the optional Maps and username callables. TTL index
deployment is a separate project operation; expiry is not required for correct
limits but avoids unbounded retention. HMAC key rotation resets active buckets.
Direct client reads/writes are denied by profile rules.

## Profile migration and release order

1. Review existing server writers, actual rules, legacy profile shapes and
   existing indexes. The production operations already completed are recorded
   separately in the release runbook; do not blindly repeat them.
2. Test/configure the backend in staging. It works both before and after profile
   email removal because Auth is authoritative. Confirm reset email delivery,
   real network/IP handling, abuse limits and normal sign-in.
3. Coordinate release of the new app and rules. Old apps query email anonymously
   and will lose username login when rules are tightened. They can use email
   sign-in; plan the minimum-version/update message before production rollout.
4. Replace the old broad profile grants with profile.fragment.rules, alongside
   the other reviewed fragments. Do not append a deny beside an old allow.
   An unconverted profile is visible only to its owner. Clients can create or
   mark version 2 only with allowed, typed fields and no email. Trusted Admin
   writers must uphold the same invariant. Never mark an unclean record v2.
5. Run a read-only profile inventory and resolve unknown fields/invalid values.
   `node tool/migrate-profiles.cjs --project=PROJECT` prints aggregate counts only.
   It does not mutate data. A production inventory and 21 conditional updates
   were completed in this session; three orphan legacy profiles remain.
   The current CLI's --apply-local is restricted to demo-depar-review with both
   localhost emulators; production writes require a separately reviewed step.
6. In an approved migration, remove email and set profileVersion:2 atomically per
   document. Existing Auth owns the email; no private Firestore copy is needed.
   The helper checks Auth existence, pages records, refuses unknown shapes and
   uses update-time preconditions to avoid overwriting concurrent edits. Retry
   stale documents. Unknown fields are retained for review, never dropped.
7. Merge firestore.indexes.candidate.json into the **existing** index inventory;
   do not replace unrelated indexes. New friend search filters profileVersion:2,
   ranges over fullName, and limits results to 20. Rules reject unbounded or
   version-unconstrained profile lists. Until migration finishes, old profiles
   are absent from search and cannot be read by other users.
8. Validate registration, Google/Apple profile creation, search, renamed/colliding
   names, recovery and login on actual devices. Publish only after the complete
   ruleset, Storage policy and rollout prerequisites have been reviewed.

Firebase whole-document reads cannot selectively hide email inside a profile:
[field access](https://firebase.google.com/docs/firestore/security/rules-fields).
Password verification and reset use the official
[Firebase Auth REST API](https://firebase.google.com/docs/reference/rest/auth).

## Local verification

`flutter test` covers the client adapter (including failure without a session and
exact-password preservation). In security-tests: test:private-login exercises
real Auth/Firestore emulators, test:profile-rules exercises the assembled rule
fragments, and the social/match suites also include profile rules.
test:combined-rules now tests the assembled Firestore candidate, including
venue and match metadata policies. Account-scoped deletion is now implemented
locally; Storage integration, migration and real staging validation remain
prerequisites for production readiness.

private-login-functions.test.cjs additionally calls actual local Functions
endpoints without an Auth token, using only synthetic users and demo settings.
Use functions.firebase.json with functions,firestore,auth emulators, project
demo-depar-review and temporary process variables PRIVATE_LOGIN_READY=true,
AUTH_WEB_API_KEY=demo-only and a synthetic AUTH_RATE_LIMIT_KEY of at least 32
characters. Do not enable deletion/moderation for this test.
