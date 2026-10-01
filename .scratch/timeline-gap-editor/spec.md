# Specification: Interactive schedule gap editing and shifting (Timeline Gaps)

## Goal
Allow direct configuration/movement of timeline and day-schedule gaps (pauses/breaks/lunch): clicking a gap opens a modal whose boundary edits automatically move adjacent task boundaries.

## Architectural rules
1. **Boundary shifts:**
   - Changing gap start ($start_G$) moves the left task's end ($L.endUtc = new\_start_G$), changing duration ($L.durationSeconds = new\_start_G - L.startUtc$).
   - Changing gap end ($end_G$) moves the right task's start ($R.startUtc = new\_end_G$), changing duration ($R.durationSeconds = R.endUtc - new\_end_G$).
   - Edge gaps: the outer boundary moves `DayDraft.startUtc` for the first gap or `DayDraft.endUtc` for the last.
2. **Constraints and validation:**
   - Work segments cannot be shorter than one minute (60 seconds). Compressing below this threshold blocks saving and shows an understandable error.
   - Jira records (`ImportedWorklog`) are immutable. A neighboring `ImportedWorklog` fixes the corresponding gap boundary.
3. **Gap deletion (closing):**
   - Extend the left task to the right task's start ($L.durationSeconds += gap.durationSeconds$). If $L$ is Jira, move/extend the right task left.
   - Start-of-day edge gap: `DayDraft.startUtc = firstTask.startUtc`.
   - End-of-day edge gap: `DayDraft.endUtc = lastTask.endUtc`.
4. **Gap type:**
   - Explicitly switch between Break (coffee) and Lunch (restaurant).
5. **UI entry points:**
   - `TimelineTrackBar`: clickable break bar with pointer cursor/hover effect.
   - `DayScreen`: clickable break card and Edit interval pencil icon.
