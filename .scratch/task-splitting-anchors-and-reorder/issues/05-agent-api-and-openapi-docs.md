# Issue 05: Agent HTTP API: fixed time, split/merge endpoints, and documentation

## Depends on:
- Issue 01 (`splitLog`, `mergeLogs` in AppState)

## Task description:
1. **Update existing log endpoints:**
   - `POST /api/logs`: optional `"fixed_start_time": "11:00"` with HH:mm validation.
   - `GET /api/logs/unsubmitted`: include `"fixed_start_time"` in log objects.
2. **New Split/Merge endpoints:**
   - `POST /api/logs/{id}/split`:
     - Input: `{ "part1_minutes": 45, "part1_description": "...", "part2_description": "..." }` (or `part1_seconds`).
     - Response: `201 Created` with the two created logs.
   - `POST /api/logs/merge`:
     - Input: `{ "source_log_ids": ["uuid1", "uuid2"], "target_issue_key": "PROJ-123", "description": "..." }`.
     - Response: `200 OK` with merged log.
3. **Update day endpoint:**
   - `POST /api/day`: support `"is_fixed": true` and `"fixed_start_time": "11:00"` in `segments` entries.
   - `GET /api/day`: return segment `is_fixed`.
4. **Documentation and OpenAPI:**
   - Update `GET /api/help` with split, merge, and fixed-time request examples.
   - Update `GET /api/openapi.json` with new parameter/endpoint schemas.
   - Update `AgentApiServer.generateSkillPrompt(...)`.

## Acceptance criteria:
- `POST /api/logs` tests with `fixed_start_time`.
- `POST /api/logs/{id}/split` success/validation tests.
- `POST /api/logs/merge` success/validation tests.
- Verify OpenAPI and help generation.
- `flutter analyze`: zero warnings.
