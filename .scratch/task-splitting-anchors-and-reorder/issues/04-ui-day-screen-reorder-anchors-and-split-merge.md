# Issue 04: Day UI: manual segment order, anchors, and split/merge

## Depends on:
- Issue 01 (`splitSegment`, `mergeSegments`, `toggleSegmentFixed`)
- Issue 02 (`rebuildDayPlan` algorithm)

## Task description:
1. **Manual segment reordering:**
   - Use `ReorderableListView` with a drag handle below the timeline.
   - Add quick-move Up `▲` and Down `▼` buttons on cards.
2. **Pinned anchors:**
   - Lock icon `🔒` / `🔓` toggles `isFixed`.
   - Visually distinguish fixed timeline segments with a lock or accent border.
3. **Split segment:**
   - Add Split to the card menu.
   - Dialog accepts split offset in minutes from the segment start.
   - Call `appState.splitSegment(...)`.
4. **Merge segments:**
   - Add Merge with... to the card menu.
   - List other segments in the current day draft.
   - Call `appState.mergeSegments(...)`.
5. **Rebuild day button:**
   - The Day action bar rebuilds while preserving current task order and fixed anchors.

## Acceptance criteria:
- `DayScreen` drag/reorder widget tests.
- Segment `isFixed` toggling test.
- Rebuild day test verifying order preservation.
- Segment splitting/merging tests.
