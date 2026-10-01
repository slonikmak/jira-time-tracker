# 0001. Two day-building modes: As-Recorded Build and Smart Rebuild

## Context

The original day builder always scaled selected logs to the working-day range (7.5–8 hours), inserted synthetic short breaks and lunch, and split every issue. With few logs, this stretched work time unnaturally and obscured the actual recorded intervals.

## Decision

Separate schedule construction into two independent workflows:

1. **As-Recorded Build (default):** invoked by **Build day** on the Work screen. Logs retain their original local times and durations (for manual logs, `start = createdAt - duration`). Issues lasting $\le 1$ hour are not split. No artificial breaks are added; overlaps and conflicts with existing Jira entries are resolved by cascading forward shifts.
2. **Smart Rebuild:** invoked explicitly by **Smart rebuild** on the Day screen. Uses algorithmic distribution with day settings, short days ($< 6$ hours), lunch ($\ge 4$ hours of work), and splitting of issues lasting $> 1$ hour.

## Consequences

- `DayBuilder` has independent `buildAsRecorded` and `build` methods.
- Default behavior preserves the developer's actual time records without distortion.
- Smart rebuilding remains an optimization tool on the Day screen.
