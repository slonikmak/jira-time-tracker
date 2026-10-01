# 01. Adjacent-boundary shifts when editing a gap (AppState & DayBuilder)

Status: resolved

## Description
Implement gap editing in `AppState` (`updateBreakGap`, `deleteBreakGap`):
1. Find left ($L$) and right ($R$) neighbors: `Segment`, `ImportedWorklog`, or day boundary.
2. Validate new boundaries:
   - $newStart < newEnd$.
   - If $L$ is `Segment`, new duration $\ge 60$ seconds.
   - If $L$ is `ImportedWorklog`, $newStart == L.endUtc$.
   - If $R$ is `Segment`, new duration $\ge 60$ seconds.
   - If $R$ is `ImportedWorklog`, $newEnd == R.startUtc$.
3. Persist changes (`store.updateSegment`, `store.updateDayDraft`, `breaks`) and call `_revalidateCurrentPlan()`, `notifyListeners()`.
4. Implement gap closing with `deleteBreakGap`.
5. Cover with unit tests.
