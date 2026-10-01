# 07: Day draft and UI schedule editor

**What to build:** Persist day draft structures (`DayDraft`, `DraftLog`, `Segment`, `Break`) in SQLite. Day screen: target-date selection, transfer selected queue logs to a draft, Build day button, and schedule table with break dividers. Inline editing of segment start/duration/description, part deletion, displayed-total recalculation, and Rebuild with a new seed.

**Blocked by:** 05: Unconsumed log queue and entry management; 06: Pure DayBuilder scheduling algorithm (breaks, locks, splitting)

**Status:** resolved

## Acceptance criteria

- [x] Persist `DayDraft`, `DraftLog`, `Segment`, and `Break` tables in SQLite. Only one unfinished draft exists for a `(scope, date)` pair.
- [x] Included logs link to the draft and cannot simultaneously enter another date's draft.
- [x] Day allows date selection, generation parameters (start, lunch, breaks), queue-log selection, and building with Build day.
- [x] The draft table shows time-ordered intervals and intervening breaks.
- [x] Users can manually edit any interval's start/duration/description; immediately validate through `DayBuilder.validate` and recalculate day/break/Jira totals (A13).
- [x] Deleting some intervals preserves remaining parts; deleting all intervals of a log releases its source to the queue (A10, A13).
- [x] Rebuild uses a new seed for a never-submitted draft; ordinary save/reopen does not randomly regenerate.
- [x] Near-midnight dates/times and time-zone changes preserve exact UTC timestamps without a day shift (A18).
- [x] SQLite draft-persistence and schedule-editing integration tests are written.

## Comments
