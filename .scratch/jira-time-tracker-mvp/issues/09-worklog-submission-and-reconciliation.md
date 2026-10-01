# 09: Jira submission, safe properties, and unknown recovery

**What to build:** `WorklogSender` for reliable, idempotent interval submission to Jira Cloud. Submit each segment individually with an ADF comment and `jira-time-tracker.segment: {id: uuid}` property. Persist SQLite states (`pending` -> `sending` -> `sent` / `failed` / `unknown`), automatically reconcile `unknown` through issue properties without blind repeated POSTs, provide manual resolution, and consume source logs only after all parts are confirmed.

**Blocked by:** 08: Existing Jira worklog loading and conflict detection

**Status:** resolved

## Acceptance criteria

- [x] Before network POST, transactionally persist `sending` and an immutable request body in SQLite; submit strictly one interval at a time (A14).
- [x] POST `/rest/api/3/issue/{idOrKey}/worklog?adjustEstimate=leave` includes `started`, `timeSpentSeconds`, ADF for nonempty descriptions, and `jira-time-tracker.segment` with `{id: segmentId}`.
- [x] A 201 response changes the segment to `sent` and stores `jiraWorklogId`. Clicking Submit again skips confirmed records (A14).
- [x] Mark source `LocalLog` as `consumed` (`consumedAtUtc != null`) only when ALL its draft segments are `sent` (A10, A14).
- [x] A disconnected connection, timeout, or ambiguous failure becomes `unknown`; restart also recovers unfinished `sending` as `unknown` (A15, A19).
- [x] Check result is available for `unknown`: `WorklogSender` loads issue worklogs, finds `jira-time-tracker.segment`, and on a match restores `sent` without a second POST (A15).
- [x] Without the property, blind repeated POST is prohibited; support manual actions to specify a created worklog ID or explicitly confirm absence and permit retry.
- [x] Integration tests simulate disconnection, partial failure, and property reconciliation.

## Comments
All requirements and acceptance criteria implemented and tested:
- `WorklogSender` freezes the body before network POST.
- Supports adjustEstimate=leave, ADF comments, and jira-time-tracker.segment safe properties.
- Partial submission skips sent records on repeat; a source becomes consumed only after all parts are confirmed.
- Jira property reconciliation restores sent for unknown results without blind retries (A15).
- Manual-resolution dialog validates IDs and explicit absence confirmation.
- Restart recovers stuck sending states.
- `test/worklog_submission_test.dart` (six tests) and the full 66-test regression suite pass.
