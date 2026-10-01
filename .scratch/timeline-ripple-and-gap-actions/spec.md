# Specification: Preserving work duration (Ripple Push) and quick gap actions

## Goal
Reduce cognitive complexity and the risk of cutting work time while editing:
1. Never automatically shorten user tasks. Extending a task/break pushes subsequent tasks right (ripple push) while preserving full durations.
2. Clicking free time opens a quick menu of clear actions:
   - 🧲 **Collapse break:** bring subsequent tasks up to the previous task.
   - ⏱️ **Extend task:** extend the previous task to the next start.
   - 🍽️ **Make lunch / Regular break:** switch gap type.
   - ✏️ **Set break duration:** choose 15, 30, 45, or 60 minutes, pushing subsequent tasks.

## Shift architecture and validation
1. **Ripple Push algorithm:**
   - If segment $S$ is extended or moved forward:
     - First consume a free window (break) before $S_{next}$.
     - If $S.endUtc > S_{next}.startUtc$, move $S_{next}$ to $S.endUtc$, preserving $durationSeconds$.
     - If this overlaps $S_{next+1}$, move it too, cascading down the chain.
   - **Jira record protection (`ImportedWorklog`):**
     - The chain cannot cross an encountered `ImportedWorklog` record's `startUtc`.
     - If required time exceeds the free window, block with an understandable error: “Not enough free time before the Jira record (X min available, Y min required).”
   - Extending the day right extends `DayDraft.endUtc` to the last segment's end.
2. **Collapse break intent (`snapGap`):**
   - Find the chain right of the gap.
   - Move its first segment left to meet the left interval (`startUtc = leftEndUtc`).
   - Move all following segments left by the removed gap ($\Delta t = gap.durationSeconds$), preserving intervening breaks.
3. **Extend task intent (`fillGapWithLeftSegment`):**
   - Extend the left segment: `durationSeconds += gap.durationSeconds`.
   - Right segments stay in place; work fills the gap.
4. **Set break duration intent (`setGapDuration`):**
   - Specify $D_{new}$.
   - Shift $\Delta t = D_{new} - D_{old}$.
   - If $\Delta t > 0$, push the right chain right by $\Delta t$, checking Jira obstacles.
   - If $\Delta t < 0$, move it left by $|\Delta t|$, narrowing the break and bringing tasks closer.
5. **Make lunch / Break intent (`toggleGapLunch`):**
   - Persist lunch preference (`store.replaceBreaks`) and recompute the schedule.
