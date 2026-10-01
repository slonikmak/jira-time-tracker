# 02. Simple gap actions interface (GapActionsDialog)

Status: resolved

## Description
Replace overloaded `EditBreakDialog` with a simple, clear `GapActionsDialog`:
1. Heading with gap time/duration, e.g. `Free time: 12:00 — 13:00 (1 h)`.
2. Quick action cards/buttons:
   - 🧲 **Collapse break:** pull tasks together, removing the gap.
   - ⏱️ **Extend task:** extend task $L$ by this time; disabled if $L$ is a Jira record.
   - 🍽️ **Make lunch** / ☕ **Make break:** switch type.
3. **Set exact duration:**
   - Chips: `15 min`, `30 min`, `45 min`, `1 hour`.
   - Manual minutes field.
   - Hint: “Following tasks will shift by X min.”
   - Apply shift button.
4. Informational banner when a Jira record blocks shifting.
5. Widget tests.
