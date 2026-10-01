# Issue 02: Day builder algorithm: fixed anchors, splitting around anchors, and order preservation

## Depends on:
- Issue 01 (Data models and `DayBuilderLogInput`)

## Blocks:
- Issue 04 (Day UI)

## Task description:
1. **Update `DayBuilderLogInput`:**
   - Fields `bool isFixed` and `DateTime? fixedStartUtc`.
2. **Place fixed anchors in `DayBuilder`:**
   - Place `isFixed == true` tasks exactly at `fixedStartUtc`.
   - Overlapping fixed anchors throw `DayBuilderException` identifying conflicting issues.
3. **Place floating tasks and preserve sequence:**
   - Process the input list strictly in order, without randomizing sequence during rebuild.
   - Free windows lie between day start, anchors, and day end.
   - If a floating task does not fit before an anchor:
     - Window $\ge 15$ minutes (900 seconds): split in two; part one fills the window, part two moves to the next window after the anchor.
     - Window $< 15$ minutes: do not split; move the whole task after the anchor.
4. **Implement `rebuildDayPlan`:**
   - Preserve the draft's existing segment sequence.
   - Respect pinned anchors.
   - Calculate optimal breaks.

## Acceptance criteria:
- Correct fixed-call placement at the specified time.
- Error for overlapping fixed calls.
- Floating-task splitting with a window $\ge 15$ minutes.
- Whole-task movement with a window $< 15$ minutes.
- Strict task-order preservation on rebuild.
