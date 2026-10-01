# 02. Visual handles and dragging on TimelineTrackBar (Ticket 02)

Status: resolved

## Description
In `lib/ui/timeline_track_bar.dart`:
1. Add drag handles at both boundaries of every work segment:
   - Hitbox width ~10–12 px.
   - Cursor: `SystemMouseCursors.resizeLeftRight` (or `resizeColumn`).
2. State `hoveredSegmentId` and `activeDragSegmentId`:
   - Hovering a handle or dragging highlights the segment with an accent border (`border: Border.all(color: AppColors.accent(isDark), width: 2)`), clearly identifying the edited task.
3. Callbacks:
   - `onResizeSegmentRight(Segment segment, int newDurationSeconds)`
   - `onResizeSegmentLeft(Segment segment, DateTime newStartUtc)`
4. Live tooltip/badge during dragging, e.g. “10:00 — 11:45 (1 h 45 min).”
5. Handle/hover widget tests.
