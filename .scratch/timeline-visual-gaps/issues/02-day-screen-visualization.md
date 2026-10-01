# 02. Computed breaks in DayScreen and day metrics

Status: resolved
Blocked by: 01

## Solution
1. `AppState`:
   - `currentBreaks` dynamically calls `DayBuilder.computeTimelineGaps(...)`.
   - `totalBreaksDurationSeconds` sums computed day gaps.
   - `_revalidateCurrentPlan` validates against actual computed breaks.
2. `DayScreen`:
   - Schedule receives current gaps between nonadjacent tasks and displays `_buildBreakCard` with exact time/duration and coffee/lunch icons.
   - Breaks accurately reports total free day time.
3. End-to-end widget test in `test/day_screen_gaps_test.dart` passes.

## Description
Connect gap calculation to `DayScreen` schedule presentation and `AppState` metrics.

## Acceptance criteria
1. `DayScreen` generates gap cards from `computeTimelineGaps` instead of static `currentBreaks`.
2. Breaks (`appState.totalBreaksDurationSeconds`) sums actual computed gaps.
3. Cards clearly show `start — end`, formatted duration, and break/lunch status.
4. Widget tests and manual verification.
