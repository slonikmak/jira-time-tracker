# 03: Issue addition and caching (key, ID, URL)

**What to build:** Add Jira issues to the local `Issue` table by key (`PROJ-123`), numeric issueId, or web link (`/browse/PROJ-123`). Fetch title (summary) through `JiraClient`. Show recent issues on Work, sorted by last action and filtered by activity age.

**Blocked by:** 01: Flutter Desktop foundation, SQLite, single-instance lock, and navigation; 02: Jira connection settings (Env, SecureStore, route verification)

**Status:** resolved

## Acceptance criteria

- [x] Parse textual keys (`PROJ-123`), numeric IDs, and browser links (`https://domain.atlassian.net/browse/PROJ-123` or `/browse/PROJ-123`).
- [x] `JiraClient.getIssue` requests GET `/rest/api/3/issue/{idOrKey}?fields=summary` and retrieves canonical key/summary.
- [x] Allow adding an issue assigned to another user and create its row (A05).
- [x] Re-entering an existing issue creates no duplicate and moves it to the top (`lastUsedAtUtc`).
- [x] Work sorts issues by activity (addition, timer start, manual log), supports key/title search and 7 days / 30 days / All filters without deleting data.
- [x] Key/URL parser tests and SQLite issue-persistence integration tests are written.

## Comments

Implemented:
- `lib/issue_parser.dart`: key, numeric ID, and Atlassian browser link (`https://.../browse/KEY`) parsing.
- `lib/jira_client.dart`: `getIssue(idOrKey)` with direct/scoped routing.
- `lib/app_state.dart`: issue catalog, automatic deduplication and `lastUsedAtUtc` updates, query/age filtering (7 days / 30 days / All), and selection mode for bulk deletion.
- `lib/ui/work_screen.dart`: left catalog column with input/Add button, search, filters, recent issues, indicators, and selection checkboxes.
- `test/issue_lookup_test.dart`: nine parser, Jira API (A05), and local catalog tests. All 27 project tests pass.
