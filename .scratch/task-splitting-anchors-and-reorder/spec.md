# Specification: Splitting, merging, fixed times (anchors), and manual segment order

## 1. Context and goal
Time-tracker users need to:
1. Manage raw time records (`LocalLog` on Work) and final day intervals (`Segment` on Day):
   - Split long records into two parts with specified time/comments.
   - Merge small records from one or different issues.
2. Fix exact starts for recurring or strictly scheduled activities, e.g. calls/meetings at 11:00.
3. Reorder tasks in a built day manually with drag-and-drop or up/down buttons.
4. Rebuild while preserving user sequence, placing fixed anchors exactly, and fitting floating tasks between them: split around an anchor if the window is at least 15 minutes, otherwise move after it.
5. Decouple raw logs from day segments: raw logs are an incoming pool of facts; a day is an independent timeline submitted to Jira.

---

## 2. Data model and storage (SQLite)

### 2.1 `local_logs` table
- Add `fixed_start_time TEXT`: local `HH:mm`, e.g. `'11:00'`, or `NULL` for floating entries.

### 2.2 `segments` table
- Add `is_fixed INTEGER NOT NULL DEFAULT 0`: 1 fixes the segment at its `start_utc`; 0 means floating.
- `source_log_id TEXT` remains a string but acts as a soft informational link (may be `NULL` or empty on manual creation/merge).

### 2.3 Dart models (`lib/models.dart`)
- `LocalLog`: `String? fixedStartTime` (HH:mm); `toMap`, `fromMap`, `copyWith`.
- `Segment`: `bool isFixed`; `toMap`, `fromMap`, `copyWith`.
- `DayBuilderLogInput`: `bool isFixed`, `String? fixedStartTime`.

---

## 3. Day building and rebuilding algorithm (`DayBuilder`)

1. **Anchors:**
   - Place `isFixed == true` segments or `fixedStartTime != null` logs exactly at their fixed time (`start_utc = localDate + fixedStartTime`).
   - Overlapping fixed segments $\to$ throw an understandable `DayBuilderException`.
2. **User sequence order:**
   - During rebuild or with predefined order, stop randomizing task sequence; follow the user's chain strictly.
3. **Floating tasks around anchors:**
   - Distribute floating tasks/breaks into free windows:
     - Window 1: `workDayStart` to first anchor.
     - Between anchors.
     - After last anchor.
   - If the next floating task does not fit before the anchor:
     - Window $\ge 15$ minutes: split in two; first fills the available window, second moves after the anchor.
     - Window $< 15$ minutes: avoid impractical fragments and move the whole task after the anchor, leaving a buffer break or shifting start.

---

## 4. User interface (UI)

### 4.1 Work screen (`WorkScreen`):
1. **Fixed start time:**
   - Manual-entry/log-edit dialogs gain start selection with Fixed time checkbox (e.g. `11:00`).
   - Log cards show a clock/lock badge (e.g. `🔒 11:00`).
2. **Split log:**
   - Split in the card menu.
   - First-part input (minutes or HH:MM), automatic remainder, and description fields for both parts.
3. **Merge logs:**
   - Merge with... in the card menu.
   - Dialog lists other free logs for the day.
   - Same issue: one-click merge, summing time/combining descriptions.
   - Different issues: target selection.

### 4.2 Day screen (`DayScreen`):
1. **Sorting and reordering:**
   - `ReorderableListView` below the timeline with mouse-drag marker.
   - Card buttons `▲` (up), `▼` (down).
2. **Fixed segment time:**
   - Lock icon toggles `isFixed` to fix the start.
3. **Split segment:**
   - Split $\to$ split-time dialog (e.g. after 30 minutes), yielding two consecutive segments.
4. **Merge segments:**
   - Merge with... $\to$ merge an adjacent or selected segment.
5. **Rebuild day:**
   - Recalculate timestamps/breaks while strictly retaining sequence and fixed anchors.

---

## 5. Agent HTTP API (`AgentApiServer`)

1. `POST /api/logs`:
   - Support `"fixed_start_time": "11:00"`.
2. `POST /api/logs/{id}/split`:
   - Body: `{ "part1_minutes": 45, "part1_description": "...", "part2_description": "..." }`.
   - Return the two created logs.
3. `POST /api/logs/merge`:
   - Body: `{ "source_log_ids": ["id1", "id2"], "target_issue_key": "PROJ-123", "description": "..." }`.
   - Return merged log.
4. `POST /api/day`:
   - Support `"is_fixed": true` and `"fixed_start_time": "11:00"` in `segments`.
   - Save segments in supplied order.
5. Update `GET /api/help` and `GET /api/openapi.json`.

---

## 6. Acceptance criteria (Definition of Done)
1. SQLite updates without losing existing data.
2. Unit tests split/merge logs (`LocalLog`) and segments (`Segment`).
3. `DayBuilder` tests cover anchors, splitting around anchors with a 15-minute threshold, and user-order preservation on rebuild.
4. Work/Day UI integration tests.
5. API tests: split, merge, fixed_start_time.
6. `flutter analyze`: zero warnings/errors.
