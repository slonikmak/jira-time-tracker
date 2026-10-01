# 0002. Timeline breaks as computed time gaps (Timeline Gaps)

## Context

Originally, breaks were static records in the `breaks` table, created only during day generation. As-Recorded Build and manual segment edits left natural gaps between issues (such as an end at 10:37 and the next start at 14:32) out of the UI element list. Issues appeared adjacent, and the day header's **Breaks** metric showed `0:00`.

## Decision

Define timeline breaks as **dynamically computed Timeline Gaps**:

1. Compute intervals between consecutive work intervals (`next.startUtc - prev.endUtc`), between the day start and first issue, and between the last issue and day end when preparing the UI schedule and metrics.
2. Do not persist gaps as separate database records, avoiding drift when segments are edited or removed.
3. Display each gap as a separate break card with exact boundaries and duration. Gaps lasting $\ge 30$ minutes in the 12:00–14:00 lunch window, or designated by Smart Rebuild, are labeled lunch.

## Consequences

- The timeline reflects the actual day regardless of build mode or manual edits.
- The day header's **Breaks** metric is calculated dynamically from actual gaps.
- The data model is simpler: editing segments does not require updating or deleting SQLite break records.
