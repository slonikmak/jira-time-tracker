# 02. Gap configuration modal (EditBreakDialog)

Status: resolved

## Description
Create `EditBreakDialog` in `lib/ui/edit_break_dialog.dart`:
1. Title: Configure break or Configure lunch.
2. Start time with TimePicker button, disabled if the left neighbor is a Jira worklog.
3. Hours and Minutes duration fields.
4. End time recalculated live.
5. Whole-interval shift buttons: -15 min and +15 min.
6. Break / Lunch type selector (`SegmentedButton` or chips).
7. Delete break button closes neighboring task intervals together.
8. Validation errors in a red container when a neighbor is compressed too far or Jira boundaries are violated.
