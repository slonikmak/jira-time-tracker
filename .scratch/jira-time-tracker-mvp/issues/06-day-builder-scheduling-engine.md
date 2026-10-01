# 06: Pure DayBuilder scheduling algorithm (breaks, locks, splitting)

**What to build:** A pure Dart `DayBuilder` with `build(input, seed)` and `validate(plan, existingWorklogs)`. Generate schedules from settings ranges: start 08:00–09:00, full duration 07:30–08:00 (maximum eight hours), lunch 12:00–14:00 for 30–45 minutes, and 2–4 short breaks of 5–10 minutes. Allocate the remaining seconds proportionally with integer arithmetic, preserve fixed logs, and split intervals over 120 minutes into 45–120-minute parts.

**Blocked by:** 01: Flutter Desktop foundation, SQLite, single-instance lock, and navigation

**Status:** resolved

## Acceptance criteria

- [x] `DayBuilder` is pure Dart, without Flutter, SQLite, HTTP, or system-clock dependencies, and receives all inputs explicitly.
- [x] Determinism: identical inputs and fixed seed produce exactly the same schedule (A06).
- [x] Duration from first start to last end, including breaks/work, is at most eight hours (<= 28,800 seconds). New intervals, breaks, and existing worklogs never overlap (A06).
- [x] Verify specification arithmetic: with one existing Jira hour, a 7:48 day (28,080 s) and 0:51 breaks (3,060 s) yield exactly 5:57 new intervals (21,420 s) and 6:57 total Jira time (A07).
- [x] `durationLocked` preserves a log's total duration; impossible placement returns an understandable error without damaging inputs (A08).
- [x] Logs over 120 minutes split into parts (usually 45–120 minutes); each references the original `sourceLogId` and copies its description (A09).
- [x] `validate` checks half-open intervals `[start, end)`, eight-hour limit, overlap absence, and valid breaks.
- [x] Comprehensive unit tests verify A06–A09 across seeds and edge cases.

## Comments
