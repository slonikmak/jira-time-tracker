# 04: Timers and manual time entry (Play/Pause, restart persistence)

**What to build:** Track issue work time with `LocalLog` records. Support manual Add time for three hours without a timer, independent parallel timers on different issues, pure `LogClock` calculations from saved UTC timestamps, and persistence through process shutdown and Windows sleep.

**Blocked by:** 03: Issue addition and caching (key, ID, URL)

**Status:** resolved

## Acceptance criteria

- [x] Manual Add time creates a stopped local log for an arbitrary duration (e.g. three hours = 10,800 seconds), optional description, no timer start, and no Jira requests (A01).
- [x] Simultaneous timers on different issues create independent records with equal durations (A02).
- [x] `LogClock` computes elapsed time as `accumulatedSeconds + (nowUtc - runningSinceUtc)`. Application closure, process shutdown, or Windows sleep correctly count elapsed time after restart (A03).
- [x] Play resumes the issue's current log; Pause stops and records elapsed time, excluding the paused period (A03).
- [x] New log stops the issue's previous timer if running and creates a separate record; manual entry with an active timer neither overwrites nor doubles other timers (A04).
- [x] A negative time difference from Windows clock rollback is recognized as an error requiring log review.
- [x] Timer/manual-entry tests cover A01, A02, A03, A04.

## Comments

Implemented:
- `lib/log_clock.dart`: pure Dart `LogClock` without direct `DateTime.now()` reading, Windows clock rollback detection (`hasClockRollback`), `formatHoursMinutes` and `formatDigital`.
- `lib/local_store.dart`: transactional `saveLogAndIssue`, `saveLogsAndIssue`, and safe log deletion clearing `issues.current_log_id`.
- `lib/app_state.dart`: `addManualLog`, `playTimer`, `pauseTimer`, `pauseLog`, `pauseAllTimers`, `createNewLogForIssue`, `startSelectedIssues`, `editLog`, `deleteLog`, and a live ticker (once per second only with active timers).
- `lib/ui/add_time_dialog.dart`: manual-entry dialog with hours, minutes, optional description, and issue selection.
- `lib/ui/edit_log_dialog.dart`: stopped-log duration/description editing.
- `lib/ui/work_screen.dart`: adaptive issue cards with activity indicators, live timers, Play/Pause/New log/Add time; right-side queue of unconsumed logs and history with day-build selection.
- `test/timer_and_logs_test.dart`: 11 tests covering A01–A04, clock rollback, and Windows sleep.
- `test/work_screen_test.dart`: A01/A03 widget tests. All 40 project tests pass. Windows binary builds without errors.
