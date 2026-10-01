# 01. Pure schedule gap calculation (Timeline Gaps)

Status: resolved

## Solution
Implemented `DayBuilder.computeTimelineGaps`:
- Collect work intervals (`Segment`, `ImportedWorklog`), merging adjacent/overlapping areas.
- Find free time before the first task, between tasks (`next.startUtc > prev.endUtc`), and after the last task to the day boundary.
- Determine break kind: `BreakKind.lunch` for gaps $\ge 30$ minutes in the 12:00–14:00 local lunch window or from `plannedBreaks`; otherwise `BreakKind.short`.
- Unit-tested in `test/timeline_gaps_test.dart`.

## Description
Implement a pure algorithm computing free time (`TimelineGap`) between work intervals and day boundaries.

## Acceptance criteria
1. `TimelineGap` model (or extended `Break`) with `startUtc`, `endUtc`, `durationSeconds`, `kind` (`BreakKind.short` / `BreakKind.lunch`).
2. `DayBuilder.computeTimelineGaps` (or `TimelineGapComputer`):
   - Accept `dayStartUtc`, `dayEndUtc`, `List<Segment>`, `List<ExistingWorklog>`.
   - Correctly merge/order intervals.
   - Find gaps before first, between adjacent intervals with `next.startUtc > prev.endUtc`, and after last up to `dayEndUtc`.
   - Label gaps $\ge 30$ minutes in the 12:00–14:00 local window as `lunch`.
3. Unit-test coverage.
