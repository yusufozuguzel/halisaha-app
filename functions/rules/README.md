# Assembled Firestore candidate — local, not approved for production

The supplied Storage policy now also has a complete local candidate. See
[STORAGE.md](STORAGE.md) for ownership, size/MIME restrictions, download-token
limitations, emulator tests and the coordinated rollout requirements.

`firestore.candidate.rules` combines the rules for all currently inventoried
Firestore paths: profiles, social relationships, nested/root notifications,
matches, venues and internal service records. Unmatched paths are denied.
It is generated with `node functions/rules/assemble.cjs` (from the repository
root). Edit fragments, then regenerate; tests reject a stale generated file.
The unsafe user-provided baseline is never included in the candidate.

The candidate has NOT been deployed and is not registered in production
firebase.json. firebase.emulator.json is local test configuration.
`npm run test:combined-rules` in security-tests tests the generated file:
33 tests, including account isolation, dense 22-player operations, profile privacy, friendship
acceptance, unknown paths and venue writes.

Production prerequisites remain: legacy/profile migration and old-client
rollout, actual Storage rules, external/Admin writer
inventory, and staging/device checks. Tests do not enable readiness flags.

## Completed in this increment

- `match-metadata.fragment.rules`: fixed field allowlist; title 1–120, venue
  <=200, venue ID <=256 (no slash), team names <=60, photo URL <=2048 and HTTPS
  or empty; numeric price 0–1,000,000; paired valid coordinates or both absent;
  integer even capacity 10–22; Timestamp dates with 30-minute to 24-hour
  duration; open/closed status and supported formations for each team size.
  Creation requires server createdAt and a future start. Rescheduling cannot
  move a match into the past; existing past matches can still be cleaned up.
- Venue/price/endDate/team names remain optional for the existing minimal
  MatchService format. Missing endDate has a one-hour validation default only;
  the rules do not write fabricated values. Supplied null/wrong-type values
  are rejected, except paired null coordinates (manual venue selection).
- Metadata is validated on creation or when it changes. Roster-only writes
  preserve it exactly and do not reevaluate unchanged metadata. Cached slot
  validation also keeps 22-player operations under the expression budget.
  Legacy unknown/malformed metadata needs review before owner editing; this
  does not silently repair stored fields or block cleanup solely due to
  unchanged legacy metadata.
- `venue.fragment.rules`: signed-in reads; ALL client writes denied, including
  moderator claims. A client-provided Google place ID/source cannot attest
  authenticity. Catalog curation remains a trusted Admin operation. Google
  and manual selections remain available, stored only on the match. They no
  longer overwrite/cache into the catalog. Failed loads no longer show mocks.
- Flutter validates metadata before saving; invalid numeric input is not
  converted into a free match. Decimal comma input is accepted. Format changes
  select a compatible formation without replacing the roster. Formation is
  validated before each invitation mutation as well as the final save.

- `social.fragment.rules`: authenticated sender, endpoint ownership, two-sided
  block/deletion checks, pending request validation, paired friendship creation
  and request removal using getAfter/existsAfter. Copied friend data must match
  its profile. Notification payloads must match the real operation. Both nested
  and root notification paths have restricted readers/writers.
- `match-ownership.fragment.rules`: authenticated ownership at creation,
  immutable createdBy/creatorId at update, canonical owner at deletion. Legacy
  creatorId-only documents use a fallback. Conflicting legacy owner fields need
  an explicit data audit; no migration was run.
- `safetyWritesAllowed()` is required on each tested write grant. Both parties
  in a new social interaction must not have a deletion job. Guards are now
  account-scoped, not global: other users' writes continue. All client updates
  to a deleting owner's match are denied. New block-list references require
  one active existing target; removals are allowed. Retired match IDs cannot
  be reused after the deletion worker removes the match. See backend README
  for transactional cleanup, late uploads, tombstones and Admin writer duties.

Run `npm run test:combined-rules` for the full candidate. The older
`test:social-rules` remains a focused ownership/social fixture; do not deploy it.
Tests use only demo emulators and synthetic users.

## Integration requirements and remaining gaps

Replace the old broad social/notification grants; adding these blocks beside
old allows provides no protection. The generated candidate already guards all
allowed client writes with safetyWritesAllowed. Venues have no client write
grant. Future grants must preserve ownership, schema and deletion protections.

The older social-only fixture deliberately tests ownership immutability only;
do not deploy it. `match-participation.fragment.rules` now supplies the actual
match grants and is tested together with the social/notification fragments by
`test:match-rules`. It limits participants to their own roster/slot changes,
enforces capacity and unique occupancy, protects reservations, validates future
open matches, and restricts metadata edits/removal of other players to the owner.
Use this complete match block instead of the old permissive match grant.

Supported formats are 5x5 through 11x11; slot keys are 0..teamSize-1 and
opponent_0..opponent_(teamSize-1). The owner remains a participant until the match
is deleted. Legacy contradictory owners, duplicate members, invalid slots,
pending users already in the roster and non-string slot values need audit and
explicit migration BEFORE enabling; these writes fail closed, not auto-repair.

`slotChange` contains only from/to/pending slot keys (no UID). It describes the
bounded change; rules independently verify each slot belongs to the authenticated
user and preserve all other slots. `inviteSlot` bounds owner reservation changes
to one slot per transaction. These descriptors avoid evaluating every possible
slot and exceeding the rules expression limit. They are not trusted permissions.

The Flutter transaction adapter re-reads the match for every join/move/leave,
kick, metadata edit and invitation response. Roster writes no longer use cached
UI snapshots. Formation saving never writes positions; it applies explicit
invitation differences one transaction at a time, then formation. Some invitations
may be saved before a later failure; UI says so and retries skip already saved
invitations. This also keeps rule document-access budgets bounded.

`profile.fragment.rules` now restricts profile reads to signed-in users and
version-2 documents (owners can still read their own legacy record). Version 2
has a typed field allowlist that excludes email and privilege fields. Search
requires a version filter and limit <= 50. Username login/reset now use a
password-verifying server endpoint; there is no anonymous profile fallback.
See [private-login rollout](../PRIVATE_LOGIN.md) for configuration, migration,
the candidate search index and old-client compatibility. Production rules and
data remain unchanged. Legacy follower/following client writes are denied;
none were found in current Flutter sources, but external writers need inventory.

The existing self-notification helper can create only its own bounded text
payload with unread state and server timestamp; it cannot impersonate another
sender or write into another user's inbox. Existing legacy notifications
with missing isRead/status fields need compatibility review. Notification
rate limiting and duplicate prevention against malicious batches are separate
remaining concerns; current Flutter deduplication is not a server guarantee.

Before deployment: complete profile/legacy migration and staging deletion validation, obtain Storage
rules, inspect legacy data, test the complete merged rules under access-call
limits, then validate normal app flows in staging. No readiness flags should
be enabled based solely on this increment.
