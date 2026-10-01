# 08: Existing Jira worklog loading and conflict detection

**What to build:** Load time already logged in Jira for a selected date through Jira Cloud API. Paginated JQL search (`nextPageToken`) with a $\pm 1$ day buffer, per-issue worklog pages (`startAt`/`maxResults`), and current-user `accountId` filtering. Display records read-only in drafts and provide them to `DayBuilder` as occupied windows.

**Blocked by:** 02: Jira connection settings (Env, SecureStore, route verification); 07: Day draft and UI schedule editor

**Status:** resolved

## Acceptance criteria

- [x] `JiraClient` finds issues with date-specific worklogs through POST `/rest/api/3/search/jql`, using a $\pm 1$ day buffer and handling `nextPageToken` pagination (A12).
- [x] Load all found issues' records through GET `/rest/api/3/issue/{id}/worklog` (`startAt`/`maxResults`), filtering `author.accountId == currentAccountId` and local calendar-day bounds (A12).
- [x] Failure of any Jira page returns an error rather than an empty day; the existing local draft is undamaged (A12).
- [x] Loaded Jira records show a Jira worklog marker in the draft table and cannot be edited locally.
- [x] DayBuilder treats external records as half-open `[started, started + timeSpentSeconds)` intervals and builds around them without overlap (A07).
- [x] If external records already exceed $> 8$ hours or overlap, the UI blocks building/submission with a conflict message.
- [x] Fake-client tests verify multipage JQL and worklog pagination.

## Comments
All criteria implemented and verified:
- JiraClient.fetchDayWorklogs uses JQL nextPageToken and GET worklog startAt/maxResults with author.accountId filtering.
- Fail-fast errors never become an empty day.
- DayBuilder plans around existing slots.
- DayScreen shows Jira records read-only and detects conflicts.
- `test/jira_worklog_discovery_test.dart` (four scenarios) and the full 60-test regression suite pass.
