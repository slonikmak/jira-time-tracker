Status: resolved

# Ticket 02: Log management and built-day endpoints (/api/logs, /api/day)

## Description
Implement business-logic handlers in `AgentApiServer`:
1. `GET /api/logs`: list free logs in the active scope.
2. `POST /api/logs`: log time against `issue_key` (minutes or seconds, optional description). If the issue is not cached, look it up/load it through JiraClient and cache it.
3. `PATCH /api/logs/{id}`: change a free log's time and description.
4. `DELETE /api/logs/{id}`: delete a free log.
5. `GET /api/day?date=...`: retrieve existing Jira records and the current day draft with segments and breaks.
6. `POST /api/day`: save a day schedule built by an agent:
   - Support local start time `"HH:MM"` and ISO-8601 UTC.
   - Automatically link existing or newly created `LocalLog` objects.
   - Validate the schedule through `DayBuilder.validate`.
   - Save `DayDraft` in `LocalStore` and update UI state through `AppState`.
7. Test all routes and edge cases in `test/agent_api_endpoints_test.dart`.
