# 01. Ripple Push algorithm and gap intents in AppState

Status: resolved

## Description
Implement and unit-test ripple shifting and gap-action calculations:
1. `canShiftRight(fromUtc, deltaSeconds)`: check whether a right shift hits an immutable Jira `ImportedWorklog`.
2. `shiftSegmentsRight({required DateTime afterUtc, required int deltaSeconds})`: cascade all segments right of `afterUtc` by `deltaSeconds`, preserving durations.
3. `snapGap(Break gap)`: collapse a gap by shifting the right chain left to meet the left interval.
4. `fillGapWithLeftSegment(Break gap)`: extend the left segment by the entire gap.
5. `setGapDuration({required Break gap, required int newDurationSeconds})`: push/pull the right chain to match the requested gap duration.
6. `toggleGapLunch(Break gap)`: switch lunch/break type and persist.
7. Unit-test Jira obstacles, edge gaps, and cascading shifts.
