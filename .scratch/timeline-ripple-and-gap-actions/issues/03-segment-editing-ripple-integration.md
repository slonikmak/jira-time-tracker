# 03. Ripple Push integration with segment editing and Day

Status: resolved

## Description
1. `updateSegment`:
   - When the user extends duration or changes start:
   - First consume free space (a break) to the right.
   - If the segment overlaps the next, push that segment and the entire following chain right (`ripple push`), preserving their durations.
   - An `ImportedWorklog` in the path blocks the operation with a validation error.
2. `DayScreen` and `TimelineTrackBar`:
   - Clicking a timeline break or schedule break card opens `GapActionsDialog`.
   - Integrate quick actions with `ScaffoldMessenger` success notifications.
3. Integration tests and full test suite.
