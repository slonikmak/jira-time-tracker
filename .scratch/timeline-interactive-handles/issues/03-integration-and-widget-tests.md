# 03. DayScreen integration and end-to-end tests (Ticket 03)

Status: resolved

## Description
1. Connect `onResizeSegmentRight` and `onResizeSegmentLeft` in `lib/ui/day_screen.dart` to `appState.resizeSegmentRight` and `appState.resizeSegmentLeft`.
2. Handle Jira obstacles with an informative SnackBar when a shift hits a Jira log.
3. Integration tests drag timeline boundaries with the mouse and verify the resulting schedule.
4. Run full `flutter test` and `flutter analyze`.
