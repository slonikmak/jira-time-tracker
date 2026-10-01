# 05: Unconsumed log queue and entry management

**What to build:** An unconsumed-log queue on Work. Display free entries with issue title, duration, creation date, and description. Edit stopped free logs' duration/description, delete entries, and retain availability regardless of creation date, including last week.

**Blocked by:** 04: Timers and manual time entry (Play/Pause, restart persistence)

**Status:** resolved

## Acceptance criteria

- [x] Work's right panel lists all unconsumed (`consumedAtUtc == null`) logs not included in drafts.
- [x] Logs created on previous days (e.g. last week) remain available and can be selected for any build date (A11).
- [x] A stopped free log can be edited (hours/minutes, description) or deleted from the database (A04).
- [x] Clearly separate Jira summary (title captured at log creation) from user work description (A04).
- [x] Active logs show In progress and a pause button, with no build selection before stopping.
- [x] Queue-management tests cover A04/A11.

## Comments

Implemented:
- The `getActiveDraftDatesBySourceLogId` method in `LocalStore` links logs to active drafts.
- `AppState` protects draft-linked logs from editing/deletion/reselection (`isLogInDraft`, `getDraftDateForLog`).
- `WorkScreen` shows In draft (DATE) badges and blocks editing/reselection of held logs.
- `test/log_queue_test.dart`: A11 (last week's logs survive issue filters and remain available), A04 (issue title independent of user description), and protection of running/draft-linked logs.
- All 44 repository tests pass.
