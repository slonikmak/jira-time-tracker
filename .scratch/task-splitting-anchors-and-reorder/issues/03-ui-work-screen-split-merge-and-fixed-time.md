# Issue 03: Work UI: log splitting/merging and fixed start time

## Depends on:
- Issue 01 (`splitLog`, `mergeLogs`, `fixedStartTime`)

## Task description:
1. **Fixed start time:**
   - Add fixed start selection (`TimeOfDay` / `HH:mm`) with clearing to manual creation (`ManualLogDialog`) and log editing.
   - Show a fixed-time badge on Work log cards (e.g. `🔒 11:00`).
2. **Split log dialog:**
   - Add Split to the log menu.
   - Show total duration, first-part duration input (minutes or HH:MM), and automatically calculated remainder.
   - Description fields for both parts default to the original description.
   - Split calls `appState.splitLog(...)`.
3. **Merge logs dialog:**
   - Add Merge with... to the log menu.
   - List free logs for the current day with issue and duration.
   - For the same issue, merge immediately on click, summing durations and combining comments.
   - For different issues, request target-issue selection.
   - Call `appState.mergeLogs(...)`.

## Acceptance criteria:
- Widget tests opening Split/Merge dialogs.
- UI splitting updates the list.
- UI merging of two logs.
- Fixed-start badge display.
