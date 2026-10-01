# 0003. Preserving work time (Ripple Push) and gap-management intents

## Context

The original gap editor (`EditBreakDialog`) changed gaps by trimming or stretching adjacent work issues: moving the break's start shortened the left issue, and moving its end shortened the right issue. This violated the user's mental model: time recorded by timers or manual entry must be protected; the system must never automatically cut worked hours. Entering start/end times for a schedule hole also burdened the user with arithmetic rather than addressing their actual task.

## Decision

### 1. Preserve issue durations (Ripple Push)

- Never automatically shorten working segments (`Segment.durationSeconds`) when moving other elements.
- **Consume empty time, then push:**
  - When an issue grows, it first occupies the gap immediately to its right; later issues stay in place.
  - If the gap is insufficient, ripple-push subsequent issues to the right while retaining their full durations.
  - When an issue shrinks, a gap appears or grows; subsequent issues do not move.
- **Immutable Jira boundaries:** `ImportedWorklog` entries stay fixed. A ripple chain stops at a Jira entry. If the available duration is insufficient, show a clear error.

### 2. Gap-management intents (Gap Actions)

Clicking a gap on the horizontal timeline or schedule offers direct intents instead of an overloaded time-arithmetic dialog:

1. **Close gap (Snap):** move the right-hand issue chain next to the left-hand issue, removing empty time by shifting later issues left.
2. **Fill gap:** extend the left issue up to the next issue's start, representing work actually performed during that time.
3. **Make lunch / Break:** switch the gap type between lunch with a restaurant icon and a short break.
4. **Set duration:** choose 15, 30, or 45 minutes, one hour, or an exact value; ripple-shift the right-hand chain to accommodate it.

### 3. Interactive issue boundaries (Timeline Drag Handles)

Manipulate issue boundaries directly on the horizontal scale:

1. **Right handle:**
   - Drag right: grow the issue and shift the entire right tail (issues and gaps) right in sync (accordion / rigid coupling).
   - Drag left: shrink the issue to a minimum of 10 minutes and move the right tail left in sync. Removed time is discarded (WYSIWYG).
   - Stop at immutable Jira `ImportedWorklog` entries on the right.
2. **Left handle:**
   - Drag left: grow into the preceding gap without trimming the previous neighbor. Stop when the gap reaches zero.
   - Drag right: shrink from the left to a minimum of 10 minutes, creating or growing the preceding gap. The left neighbor stays fixed.
3. **Hover and drag feedback:**
   - Highlight the active issue with a contrasting outline when hovering over a handle; use `SystemMouseCursors.resizeLeftRight` / `resizeColumn`.

## Consequences

- Worked hours are protected from accidental trimming, keeping edits transparent and predictable.
- Most actions take one click or a quick drag.
- Ripple-shift arithmetic is deterministic and safe around Jira entries.
