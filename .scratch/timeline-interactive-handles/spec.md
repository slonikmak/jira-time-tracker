# Specification: Interactive task boundaries on the timeline (Timeline Drag Handles)

## Goal
Allow intuitive direct mouse manipulation of work-task boundaries on the horizontal timeline, without opening time-entry dialogs.

## Logic and behavior rules

### 1. Task right edge (Right Handle)
- **Drag right:**
  - Extend the task: $\Delta t > 0$.
  - Shift the entire right-hand tail (all following tasks/breaks) right by $\Delta t$.
  - Preserve relative distances between following tasks/breaks.
  - An `ImportedWorklog` limits movement to the available free window (hard stop).
- **Drag left:**
  - Shorten the task: $\Delta t < 0$.
  - Minimum duration: **ten minutes** (600 seconds).
  - Pull the entire right-hand tail left by $|\Delta t|$.
  - Removed time is not returned to the source log (WYSIWYG: the draft records actual placement).

### 2. Task left edge (Left Handle)
- **Drag left:**
  - Extend left: decrease `startUtc`, increase `durationSeconds`.
  - Consume the preceding free break.
  - **Never shorten** the left neighbor.
  - When the break reaches zero or the day-start boundary, stop; further left movement is prohibited.
- **Drag right:**
  - Shorten from the left: increase `startUtc`, decrease `durationSeconds`.
  - Minimum duration: **ten minutes**.
  - Increase or create the preceding break.
  - The left neighbor and all other tasks stay stationary.

### 3. Feedback and highlighting (Hover / Active State)
- Handles ~8–12 px wide at each work segment's edges.
- Hover changes the cursor to `SystemMouseCursors.resizeLeftRight` (or `resizeColumn`).
- Hovered/dragged segments have a contrasting accent outline (`AppColors.accent` / bright border), avoiding ambiguity at zero-gap joints.
- During dragging, show current boundary time (e.g. `14:30`) or task duration in a tooltip.
- Drag completion calls `AppState`, persists locally, and revalidates.
