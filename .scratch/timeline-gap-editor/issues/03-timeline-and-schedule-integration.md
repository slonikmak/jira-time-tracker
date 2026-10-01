# 03. Timeline and day schedule integration (TimelineTrackBar & DayScreen)

Status: resolved

## Description
1. `TimelineTrackBar`:
   - Add a `Break` reference to `_TrackItem` when `isBreak == true`.
   - Add `onEditBreak: (Break breakItem)?`.
   - Break items respond visually: `SystemMouseCursors.click`, InkWell with onTap.
2. `DayScreen`:
   - Make `_buildBreakCard` clickable (`InkWell`); add right-side Edit interval `IconButton` (`Icons.edit_outlined`).
   - Pass `onEditBreak` to `TimelineTrackBar`.
   - `_openEditBreakDialog(BuildContext context, Break breakItem)` opens `EditBreakDialog` with neighbor information and save/delete callbacks.
3. Run all tests and linters.
