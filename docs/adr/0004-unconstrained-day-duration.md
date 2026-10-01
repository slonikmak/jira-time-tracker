# 0004. Removing the artificial eight-hour day-duration limit

## Context

An early MVP rule stated that the entire day, from start to end including breaks, must not exceed eight hours (28,800 seconds). Exceeding this threshold caused validation to fail and disabled **Submit to Jira**.

In practice, this repeatedly blocked developers:

- A normal eight-hour workday with lunch (such as 09:00–18:00 with a 45-minute break) spans 8.75–9 hours.
- Overtime and long gaps between morning and evening activities blocked submission.
- Jira REST API does not require worklog totals or the span between entries to fit into eight hours.

## Decision

1. Remove the artificial blocking eight-hour limit (`plan.totalDaySeconds > 8 * 3600`) from `DayBuilder.validate`.
2. Use actual physical limits:
   - Total day duration cannot exceed 24 hours (`totalDaySeconds <= 86400`).
   - Total logged work time cannot exceed 24 hours.
   - The minimum working segment is 10 minutes (600 seconds).
3. The Day screen's **Work**, **Breaks**, and **Total** statistics display actual time as information without blocking submission.

## Consequences

- Normal workdays with lunch and overtime can be submitted.
- The rules match real user behavior and Jira's protocol.
