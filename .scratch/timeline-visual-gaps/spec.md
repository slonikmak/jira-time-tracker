# Specification: Dynamically computed timeline breaks (Timeline Gaps)

## Goal
Present day schedules accurately and clearly: compute/display all gaps between tasks, including natural As-Recorded gaps and gaps after manual segment editing, as break cards; reflect total free time correctly in day metrics.

## Requirements
1. **Gap calculation:**
   - Input all occupied work intervals: `Segment` (new) and `ExistingWorklog` (already in Jira).
   - Order by `startUtc`.
   - A positive gap between `prev.endUtc` and `next.startUtc` (`next.startUtc > prev.endUtc`) creates `TimelineGap` with start/end, seconds, and lunch/break kind.
   - Also create positive edge gaps before first (`dayStartUtc` .. `first.startUtc`) and after last (`last.endUtc` .. `dayEndUtc`).
2. **Kind:**
   - A gap $\ge 30$ minutes overlapping the 12:00–14:00 local lunch window, or corresponding to Smart Rebuild's planned lunch, is `BreakKind.lunch`; otherwise `BreakKind.short`.
3. **Day metrics:**
   - Breaks in Day's header (`totalBreaksDurationSeconds`) sums all computed day gaps.
4. **DayScreen visualization:**
   - Insert computed gaps into schedule items chronologically.
   - Each `_buildBreakCard` shows time (e.g. `10:37 — 14:32`), duration (e.g. `3 h 55 min`), coffee/food icon, and Break / Lunch label.
