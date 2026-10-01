# Issue 01: Database, models, and core Split & Merge operations in AppState

## Blocks:
- Issue 02 (Day builder algorithm)
- Issue 03 (Work UI)
- Issue 04 (Day UI)
- Issue 05 (Agent API)

## Task description:
1. **SQLite schema (`lib/local_store.dart`):**
   - Migrate `local_logs`: add `fixed_start_time TEXT`.
   - Migrate `segments`: add `is_fixed INTEGER NOT NULL DEFAULT 0`.
   - Preserve existing-database compatibility through `PRAGMA table_info`.
2. **Models (`lib/models.dart`):**
   - `LocalLog`: add `String? fixedStartTime`.
   - `Segment`: add `bool isFixed`.
   - Update `toMap`, `fromMap`, `copyWith`.
3. **Methods in `LocalStore` / `AppState`:**
   - `splitLog({required String logId, required int part1DurationSeconds, String? part1Description, String? part2Description})`: split into two logs, preserving date/issue.
   - `mergeLogs({required List<String> logIds, String? targetIssueId, String? description})`: merge several logs, summing duration.
   - `splitSegment({required String segmentId, required int splitOffsetSeconds, String? part1Description, String? part2Description})`: split a day segment into consecutive segments.
   - `mergeSegments({required String segmentId1, required String segmentId2})`: merge two day segments.
   - `toggleSegmentFixed(String segmentId)`: toggle `isFixed`.
   - Soft unlinking when deleting draft segments.

## Acceptance criteria:
- SQLite migration tests proving no data loss.
- Unit tests for `splitLog`, `mergeLogs`, `splitSegment`, `mergeSegments`.
- `flutter analyze` without errors.
