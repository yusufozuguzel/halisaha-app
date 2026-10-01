# Moderation and blocking — local implementation

Nothing in this change is deployed. `MODERATION_READY` stays false until the
Firestore candidate, the real Storage policy, worker permissions, staffing and
support contact are reviewed together. Existing broad allow blocks must be
replaced, not supplemented with separate deny rules.

## Moderator actions

All administrative callables independently require a verified `moderator: true`
claim, authentication within five minutes, and an account with no deletion job
or moderation restriction. The app cannot grant this role. No real role was set.

- `moderationQueue({kind, after})`: pages of 50 open reports or restrictions,
  ordered by document ID. Report previews contain only title/name, venue/position,
  avatar URL and the target's exact update-time version. No emails or reporter
  identity are returned by this endpoint.
- `reviewContentReport`: starts a review or dismisses it. Missing targets can be
  dismissed; simply sending `resolved` cannot pretend an enforcement action ran.
- `applyModerationAction({reportId, action, version})`: checks the current target
  version transactionally. A changed/deleting target must be reviewed again.
  `removeMatch` deletes the match and retires its ID atomically with the report.
  `restrictAccount` creates a server-owned write barrier; it does not delete
  existing content or disable Firebase Authentication.
  `redactProfile` also replaces display text/avatar fields and queues removal of
  the exact profile photo (including listed versions) and stored social copies.
- `restoreModeratedAccount({uid, reportId})`: cannot clear a newer restriction.
  It works even if account deletion removed the original reporter's report.
  Pending profile cleanup prevents restoration and overlapping cleanup jobs.

Every destructive action has an explicit confirmation in the moderator screen.
Restriction and removal are separate choices. Restriction preserves login,
reading, reporting and the server account-deletion workflow. The account sees
an explanatory banner on Home and profile setup. Profile setup also links to
account settings so an incomplete, restricted profile can still delete its account.
It blocks all client Firestore writes through the shared
guard, including already-issued ID tokens. The Storage helper blocks writes
using the same server-owned document. It is NOT a complete login ban or an
automatic removal of all matches belonging to that account.

## Cleanup and recovery

`cleanupModeratedMatch` handles `_moderationRemovals/{reportId}` creation with
retry enabled, one instance and one concurrent request. Match jobs remove
subcollections and notification copies. Profile jobs process Storage first, then
friends/followers/following/requests/notifications. Scans are paged at 100 and
checkpointed only after successful pages. Cleanup is idempotent; failure leaves
the job pending, and profile restriction remains until cleanup completes.

The Storage finalized trigger also removes an exact newly uploaded generation
for a restricted account. This covers late completions eventually; Firestore
and Storage do not provide one cross-service atomic transaction. Before enabling,
verify actual bucket paths/region, download-token access, versioning/soft-delete
retention, trigger delivery and late-upload/restoration races in staging.
External avatar URLs cannot be erased from their remote host; the application
reference is removed. Previously downloaded device/network caches are not erased.

The Storage helper uses both permitted Firestore lookups (deletion job and
restriction). The real policy must preserve owner, file-size and MIME checks
without adding an unbudgeted third lookup. See [Firebase rule limits](https://firebase.google.com/docs/rules/rules-behavior).

Admin SDK writers bypass rules: profile migration and other server writers must
honor these barriers or be paused during cleanup. Monitor pending jobs and retry
exhaustion. A trusted operator must re-execute an existing failed job; repeated
client calls do not create another trigger. Define retention for audit records,
removed-ID tombstones and jobs before launch. Account deletion now removes the
account's restriction/profile jobs and clears moderator/restorer references.

## Blocking in Flutter

One shared block stream drives discovery, friend lists/search, invitations,
notifications/unread counts and the activity feed. Cached results are filtered
when rendered, so late async responses and undo cannot restore blocked content.
Before the initial block list is ready, those lists reveal no user content.
Activity match/profile streams remove stale deleted/redacted content and close
on controller disposal. The existing feed scope remains at most ten friends.

These are the current user's display preferences. They do not make public
profile/match reads private. Two-sided blocking of social and match interactions
is enforced separately by the server rules. Existing joined matches remain
accessible from My Matches so a user can leave/manage their commitments.

## Verification

`moderation.test.cjs` tests role/recent-auth guards, stale previews, write barriers,
restricted-account deletion/reporting, restoration, paginated removal/queues,
Storage failure recovery and missing-target dismissal using synthetic records.
`functions.test.cjs` exercises the actual callable endpoints and triggers in
local Auth/Firestore/Functions/Storage emulators. Flutter tests cover reactive
block visibility and explicit moderator confirmation/version payloads.

Production Firebase configuration, staff assignment, support/appeal contact,
real iPhone sign-in and release archives remain separate release work.
