# 01. Boundary-shift calculations in AppState (Ticket 01)

Status: resolved

## Description
Implement direct segment-boundary manipulation in `AppState`:
1. `resizeSegmentRight(Segment segment, int newDurationSeconds)`:
   - Clamp `newDurationSeconds >= 600` (minimum ten minutes).
   - Calculate $\Delta t = newDurationSeconds - segment.durationSeconds$.
   - Update `durationSeconds = newDurationSeconds`.
   - For $\Delta t > 0$, check `ImportedWorklog` obstacles through `canShiftSegmentsRight`; use the largest permitted delta or throw/limit the shift.
   - Shift all right-side segments (`s.startUtc >= segment.endUtc`) by $\Delta t$.
   - Shift all right-side `Breaks` (lunches) by $\Delta t$.
   - Extend `DayDraft.endUtc` automatically if the last segment crosses it.
2. `resizeSegmentLeft(Segment segment, DateTime newStartUtc)`:
   - Find the left neighbor: previous segment, `ImportedWorklog`, or `DayDraft.startUtc`.
   - Left limit: `minStart = max(leftNeighbor.endUtc, dayDraft.startUtc)`; clamp `newStartUtc < minStart` to `minStart`.
   - Right limit: `maxStart = segment.endUtc.subtract(Duration(minutes: 10))`; clamp `newStartUtc > maxStart` to `maxStart`.
   - Compute `newDurationSeconds = segment.endUtc.difference(newStartUtc).inSeconds`.
   - Update `segment.copyWith(startUtc: newStartUtc, durationSeconds: newDurationSeconds)`.
   - Recompute or remove the preceding gap.
3. Unit-test every boundary condition and obstacle.
