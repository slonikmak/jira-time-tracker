# Specification: Embedded HTTP server for AI agent interaction (Local Agent API)

## Goal
Provide a local HTTP interface (REST/JSON) through which external AI agents, scripts, and MCP servers can:
1. Query and log work time by Jira issue number.
2. List free unsubmitted logs to prepare a schedule.
3. Read the current day state, including records already saved in Jira.
4. Upload a complete agent-built day schedule (`DayDraft`) with validation, without using the built-in scheduling algorithm.
5. Retrieve machine-readable OpenAPI 3.0 documentation and text help.
6. Connect easily using a ready-made skill prompt available to copy in Settings.

## Network parameters and security
- Host: strictly `127.0.0.1` (`InternetAddress.loopbackIPv4`). LAN requests are blocked at the socket level.
- Port: `8765` by default. If occupied, automatically fall back to the next free port (`8766`, `8767`...) and record it in `AppState` and the UI.
- Authentication: none required (a developer's local loopback process).
- Exchange format: `application/json; charset=utf-8`.
- CORS: allow `*` with headers `Content-Type, Authorization` and methods `GET, POST, PATCH, DELETE, OPTIONS` for compatibility with web/browser tooling.

## Endpoints

### 1. `GET /api/help`
Text/Markdown help describing every route with `curl` examples.

### 2. `GET /api/openapi.json`
Complete OpenAPI 3.0.0 specification for automatic connection by agents and MCP servers.

### 3. `GET /api/logs`
Returns free unsubmitted local logs:
```json
[
  {
    "id": "uuid",
    "issue_id": "1001",
    "issue_key": "PROJ-123",
    "issue_title": "Fix auth token issue",
    "duration_seconds": 3600,
    "duration_minutes": 60,
    "description": "Debugging JWT token expiration",
    "created_at": "2026-09-17T08:00:00Z",
    "is_manual": true
  }
]
```

### 4. `POST /api/logs`
Add newly spent time:
```json
{
  "issue_key": "PROJ-123",
  "duration_minutes": 45,
  "description": "Refactoring middleware"
}
```
*`duration_seconds` is also supported.*
If the issue is absent from the local cache, the server looks it up through `JiraClient` (search/lookup), caches it, and links the log. If Jira has no such issue, return `404 Not Found`.

### 5. `PATCH /api/logs/{id}`
Update a free log: `{ "duration_minutes": 50, "description": "Updated notes" }`.

### 6. `DELETE /api/logs/{id}`
Delete a free log.

### 7. `GET /api/day?date=YYYY-MM-DD`
Day information (defaults to today):
- `date`: `YYYY-MM-DD`
- `existing_worklogs`: array of existing Jira records for the date (`[start, end]`, `duration_minutes`, `issue_key`, `description`).
- `draft`: current day draft, if any, including `segments`, `breaks`, total hours, and status.

### 8. `POST /api/day`
Upload a complete agent-built day schedule:
```json
{
  "date": "2026-09-17",
  "segments": [
    {
      "issue_key": "PROJ-123",
      "start": "09:00",
      "duration_minutes": 90,
      "description": "Code review & bugfix",
      "source_log_id": "optional-uuid"
    }
  ]
}
```
- Supports `start` as local time `"09:00"` / `"09:00:00"` or ISO-8601 UTC `"2026-09-17T09:00:00Z"`.
- Checks the schedule through `DayBuilder.validate` (no overlap between segments and existing Jira records, calendar-day limit).
- Saves `DayDraft` in SQLite.
- Updates the Day screen in real time.
- A person performs final submission using Submit to Jira on the Day screen.
