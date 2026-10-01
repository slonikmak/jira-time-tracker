# Jira Time Tracker — user stories and agent scenarios

Date: 2026-09-25.

## 1. Document purpose

This document describes the product from the perspective of people and local AI agents: who uses Jira Time Tracker, why, and what result they obtain. It maps scenarios without duplicating detailed implementation rules.

Related sources of truth:

- exact rules for time, building, Jira, and criteria A01–A24 — [MVP specification](jira-time-tracker-mvp.md);
- screens and state presentation — [UX/UI](../design/UX.md);
- entities, modules, and transactions — [ARCHITECTURE.md](../../ARCHITECTURE.md);
- terminology — [CONTEXT.md](../../CONTEXT.md);
- the boundary and rationale for the Local Agent API — [ADR-0006](../adr/0006-local-agent-http-server.md);
- the running application's actual HTTP contract — `GET /api/openapi.json`; human-readable help — `GET /api/help`.

A user story records value and an observable outcome, but does not itself prove implementation. Related automated tests and manual scenarios A01–A24 provide verification.

## 2. Actors and shared boundaries

| Actor | Role |
|---|---|
| User | Tracks time, edits the queue and day, reviews the result, and alone confirms submission to Jira. |
| Local AI agent | Creates and edits local logs through the Local Agent API, reads day state, and can prepare a draft. |
| Jira Cloud | Supplies issues and existing worklogs; accepts new worklogs only after a user action. |
| Second application instance | Can read data, but cannot change it or submit worklogs while another instance owns the lock. |

Shared product constraints:

- The UI and Local Agent API use the same local `Issue`, `LocalLog`, and `DayDraft`.
- Creating a log or draft publishes nothing to Jira.
- The Local Agent API provides no final day submission action.
- Before submission, a person sees the final timeline and explicitly clicks “Submit to Jira.”
- The API is available only on the current computer's loopback interface; the application must be running.
- The Jira token is neither passed to the agent nor returned by the API.

## 3. User stories in the application

### US-H01. Connect to Jira safely

**As a user, I want** to verify and save my Jira Cloud connection **so that** the application can find issues, read my day, and submit worklogs I have approved.

Criteria:

- Connection verification neither creates nor changes worklogs.
- Both regular and scoped token routes are supported.
- Saved settings take precedence over environment variables; cancellation does not change the active connection.
- The token is stored outside SQLite, source files, and logs.
- Changing the Jira site or account changes the scope and prevents submission of an old draft belonging to another connection.

Coverage: A16, A17.

### US-H02. Add the Jira issue I need

**As a user, I want** to add an issue by key, numeric ID, or URL **so that** I can track time against it regardless of assignee.

Criteria:

- Jira returns the canonical key, title, and available status.
- Adding an existing issue again moves it up the list without creating a duplicate.
- Search and activity-age filters change visibility without deleting issues or logs.

Coverage: A05.

### US-H03. Record time manually in a few steps

**As a user, I want** to enter an issue, duration, and optional description without starting a timer **so that** I immediately obtain a stopped log in the queue.

Criteria:

- Duration is positive; hours and minutes are validated before saving.
- A fixed local start time can be specified.
- Manual entry neither stops nor replaces running timers.
- Saving a log does not perform a POST to Jira.

Coverage: A01, A04.

### US-H04. Run several independent timers

**As a user, I want** to track work on several issues simultaneously **so that** context switches do not mix records.

Criteria:

- Timers for different issues are independent.
- Stopping records the accumulated time; a new start creates a new log according to the specification.
- Paused time is excluded; application shutdown and Windows sleep do not lose elapsed time.
- A running log cannot be included in a day build until stopped.

Coverage: A02–A04.

### US-H05. Prepare the log queue

**As a user, I want** to correct, delete, split, and merge free logs **so that** the queue reflects work actually performed before building a day.

Criteria:

- A free stopped log can be edited or deleted.
- A log can be split into two positive parts; several free logs can be merged.
- A running, consumed, or submission-protected log cannot be changed destructively.
- A log in a draft for another date displays that date instead of a misleading checkbox.
- Before the first submission, the user can explicitly remove a log from a draft and return it to the queue.

Coverage: A04, A10, A11, A13.

### US-H06. Build selected logs for the required date

**As a user, I want** to select stopped logs and a date **so that** I obtain a local day draft without publishing it to Jira.

Criteria:

- A log's creation date does not constrain its eventual day date.
- The default “Build day” command places logs on the timeline using As-Recorded Build.
- A log belongs to at most one unfinished draft at a time.
- Selected logs never disappear silently; an impossible build returns an understandable error and preserves the previous draft.

Coverage: A06, A08, A10, A11.

### US-H07. Obtain a realistic schedule

**As a user, I want** to run Smart Rebuild with breaks, long-work splitting, and preserved constraints **so that** I can quickly obtain a plausible working day.

Criteria:

- The builder respects saved `DaySettings`, fixed durations, and fixed starts.
- All selected logs are represented, totals reconcile, and intervals do not overlap one another or existing Jira worklogs.
- Splitting does not change the source local log; parts retain their source link.
- Manual edits are replaced only after explicit rebuild confirmation.

Coverage: A06–A09.

### US-H08. Review and correct a day draft

**As a user, I want** to see the timeline, sources, breaks, and totals and edit work intervals **so that** the day reflects the facts before submission.

Criteria:

- Starts, durations, descriptions, order, and interval locks can be changed; intervals can be split, merged, or deleted.
- Changing an interval or break recalculates subsequent positions, totals, and conflicts according to Ripple Push rules.
- A validation error blocks submission without destroying the saved draft.
- Before submission, the whole draft can be cleared and its sources returned to the queue for a new build.
- Once submission starts, membership and date are protected from rebuilding.

Coverage: A09, A10, A13, A18, A27.

### US-H09. See time already submitted to Jira

**As a user, I want** to see my existing Jira worklogs when opening a date **so that** I understand time already recorded and avoid duplicates.

Criteria:

- Records are loaded directly from Jira for the selected local date and current accountId.
- Pagination, time zones, and worklogs around midnight are handled explicitly.
- Failed or incomplete loading is never presented as an empty day.
- Jira records are read-only and remain visible even without a local `DayDraft`.

Coverage: A07, A12, A13, A18.

### US-H10. Submit a day without duplicates

**As a user, I want** to explicitly submit a reviewed draft to Jira and safely continue after a partial failure **so that** no interval is lost or submitted twice.

Criteria:

- Each `Segment` is submitted separately; already confirmed `sent` segments are not repeated.
- A source log becomes consumed only after all remaining parts are confirmed.
- An ambiguous network result becomes `unknown` rather than being retried automatically.
- Reconciliation using the service property or manual linking restores a confirmed worklog without a second POST.

Coverage: A10, A14, A15.

### US-H11. Continue after restarting or in a second window

**As a user, I want** to find timers, the queue, and drafts in a consistent state after restarting **so that** an application failure does not lose time or cause repeated submission.

Criteria:

- Local data and active timers are restored.
- An unfinished `sending` state is recovered as `unknown`.
- A second instance is read-only and performs no mutations or submission.

Coverage: A03, A14, A15, A19.

### US-H12. Configure quick issues for my Jira account

**As a user, I want** to save frequently used Jira issues in my connection's catalog **so that** I can quickly create logs without a built-in list from someone else's company.

Criteria:

- The catalog is initially empty and belongs to a Jira site/account pair.
- An issue is added by key, ID, or URL only after successful Jira verification; key and summary are not replaced with local values.
- An optional local hint is edited separately; entries appear in insertion order.
- Removing a shortcut does not delete Issue, LocalLog, DayDraft, Segment, or history.
- An empty menu on the Work screen opens the Quick issues settings section; selecting an entry opens manual entry with that issue selected.
- Settings have four sections in left-side navigation; the theme remains in the header and there is no global save button.

Coverage: the separate “Configurable quick issues and new settings structure” specification.

## 4. Local AI agent stories

### US-A01. Discover available actions

**As a local AI agent, I want** to obtain the current API address and machine-readable contract **so that** I can use the application without knowing its internal code.

Criteria:

- The user copies a ready-made instruction containing the actual server URL from Settings.
- `GET /api/help` describes scenarios and examples; `GET /api/openapi.json` returns OpenAPI 3.0.
- `GET /api/quick-issues` returns quick issues in the active Jira scope, their titles, and local hints.
- `GET /api/issues/{issueKey}/worklogs` returns available Jira records for a particular issue.
- The agent does not assume a fixed port: on a conflict, the application may select the next free port.

### US-A02. Log completed work

**As a local AI agent, I want** to create a stopped log for a verified Jira issue, optionally selecting it from the user's quick issues, **so that** my work appears in the user's shared queue.

Criteria:

- `POST /api/logs` accepts `issue_key`, positive duration, optional description, and `fixed_start_time`.
- If the issue is not yet stored locally, the application resolves it through Jira and caches it.
- The response returns the created log with its ID; the same log immediately appears in the UI.
- The operation does not submit a worklog to Jira.

### US-A03. Review and correct the queue

**As a local AI agent, I want** to read the queue and correct a free erroneous entry **so that** I leave the user an understandable set of sources.

Criteria:

- `GET /api/logs` returns unconsumed logs with issue, duration, description, and fixed start.
- The queue can be filtered by text, issue key, and availability `free`, `running`, or `in_draft`; a linked source includes its draft date.
- `GET /api/issues?q=...` searches locally known issues by key and title so the agent can select a source without guessing.
- `PATCH /api/logs/{id}` changes permitted fields of a free log.
- `DELETE /api/logs/{id}` deletes only a log that domain rules allow deleting.
- An invalid ID, format, or state returns an explicit error without a partial mutation.

### US-A04. Prepare independent sources

**As a local AI agent, I want** to split or merge free source logs **so that** I can prepare independent work facts before assigning them to days.

Criteria:

- `POST /api/logs/{id}/split` splits a free stopped log into two positive parts.
- `POST /api/logs/merge` accepts at least two free logs and can specify a target issue and final description.
- Running, consumed, and draft-linked logs are protected from these operations.
- Splitting a LocalLog is necessary when its parts need independent lifecycles, particularly placement in different days. Splitting one source into several intervals within a day creates several `Segment` objects, not new LocalLog objects.

### US-A05. Read the selected day's state

**As a local AI agent, I want** to request the state of a calendar date **so that** planning accounts for existing Jira worklogs and the current draft.

Criteria:

- `GET /api/day?date=YYYY-MM-DD` returns the date, existing Jira worklogs, and a local draft with segments and breaks.
- The response concerns the requested local date and never substitutes an empty list for a Jira error.
- The response contains a deterministic day-state `revision` to prevent overwriting newer manual edits.
- Existing Jira worklogs are read-only; new work intervals may run in parallel with them.
- Times use an unambiguous format sufficient for correct operation in the local time zone.

### US-A06. Provide a complete day plan

**As a local AI agent, I want** to save intervals I have calculated as a `DayDraft` **so that** the user sees them on the normal Day screen and can review them before submission.

Criteria:

- Before planning, the agent retrieves saved ranges and the user's text rule in one `GET /api/day-settings` request; it does not use a stale copy from an instruction.
- `POST /api/day` accepts a date and a complete nonempty set of segments with required `source_log_id`, start, positive duration, optional description, and `is_fixed`.
- Each source already exists, is stopped and unconsumed, and is not held by another draft; the segment's issue is derived from its source rather than accepted as independent truth.
- One LocalLog can be represented by several Segment objects on the same day. It retains one DraftLog with a snapshot of the full source duration; each Segment becomes a separate Jira worklog.
- If a draft already exists for the date, the request supplies `base_revision` obtained from `GET /api/day`; a stale version is rejected without changes.
- The application checks date boundaries and breaks, allows overlapping work intervals, and atomically replaces only a complete valid draft for the selected date.
- A successful plan appears in the UI; invalid input does not damage the previous draft.
- The operation does not submit worklogs to Jira.

Coverage: A21–A24, A28.

### US-A07. Hand control to a person

**As a local AI agent, I want** to finish at a saved log or draft **so that** the final Jira decision remains with the user.

Criteria:

- The agent reports what was created or changed and gives the result's date/ID.
- The user can edit the agent's result using the same UI controls.
- Final submission is possible only through an explicit user action in the application.

### US-A08. Fail safely on unavailability or conflict

**As a local AI agent, I want** an explicit error when the application is unavailable, read-only, or receives invalid data **so that** I do not claim time was saved when it was not.

Criteria:

- A network failure, HTTP error, or validation error counts as failure until a confirmed API response.
- The agent does not bypass the loopback API by writing directly to SQLite and does not request the Jira token.
- After an ambiguous client failure, the agent reads state before repeating a mutation.

### US-A09. Read Jira history for an issue

**As a local AI agent, I want** to retrieve existing worklogs for a selected Jira issue **so that** I can answer what was logged against it and when.

Criteria:

- `GET /api/issues/{issueKey}/worklogs` reads all available issue records with pagination, regardless of date, including other authors' records.
- The response contains author, start, duration, and description; `is_mine` identifies the current Jira account's records.
- A Jira error is never presented as empty history. Reading neither creates worklogs nor changes the local queue.

### US-A10. Read a Jira issue card and download an attachment

**As a local AI agent, I want** to obtain issue text, all visible comments, and attachment metadata **so that** I understand the work context and can separately download a required file.

Criteria:

- `GET /api/issues/{issueKey}` fetches current Jira data, loads all comment pages, and returns description and comment text with authors and dates.
- Each attachment is represented by metadata and `download_path`; binary content is not included in the issue-card response.
- `GET /api/issues/{issueKey}/attachments/{attachmentId}` serves a file only if its ID belongs to the specified issue; a Jira error does not become an empty successful response.
- Reading neither changes the local queue nor creates worklogs.

## 5. Shared end-to-end scenarios

### E2E-01. The agent completes work; the user builds and submits the day

1. The user starts the application and gives the agent the Local Agent API instruction.
2. The agent works on `PROJ-123` and creates a local log through `POST /api/logs`.
3. The user sees the entry in the queue alongside manual and timer-created logs.
4. The user selects logs and a date, builds the day, and edits it as needed.
5. The user reviews existing Jira worklogs and explicitly submits the draft.

Result: the agent automated recording work, but Jira changed only after human confirmation.

### E2E-02. The agent prepares an entire day draft

1. The agent reads `GET /api/day?date=...` and obtains Jira worklogs, the current draft, and its `revision`.
2. The agent selects existing free LocalLog objects, builds a complete set of Segment objects linked back to their sources, places work in parallel with other worklogs if needed, and submits the snapshot through `POST /api/day` with `base_revision`.
3. The application validates and saves `DayDraft` or returns an error without damaging previous state.
4. The user opens Day, checks the timeline, sources, and totals, then edits or submits it.

Result: the agent can plan, but cannot bypass visual review and human-in-the-loop submission.

### E2E-03. A person and agent correct the same queue

1. The user creates a timer log; the agent creates another log through the API.
2. The agent retrieves the current queue with source availability and, if needed, splits a log across different days or merges related free sources.
3. The UI updates from the same `AppState` and shows the new membership without separate synchronization.
4. After a log enters a draft, domain rules reject the agent's attempt to change it destructively.

Result: UI and API remain two interfaces to one model rather than independent stores.

### E2E-04. An error does not become false success

1. The agent submits an invalid log/plan or calls a stopped application.
2. The agent receives an HTTP or network error and reports that the result was not saved.
3. Before retrying, the agent reads the queue or day and checks whether the expected object appeared.
4. If a second application instance is read-only, the user returns to the writable instance.

Result: local data is undamaged, Jira is unaffected, and the person knows the actual outcome.

### E2E-05. The user configures a recurring Jira issue

1. The user connects Jira and opens Settings → Quick issues.
2. The application retrieves an issue from Jira by key or URL; the user adds an optional hint and saves the shortcut.
3. On Work, the issue appears in the menu in insertion order and opens manual time entry.
4. The Local Agent API returns the same entry with its local description only in the active Jira scope; the agent can add a shortcut, change its description, or remove it through the API.
5. Removing the shortcut removes it from the menu and API while retaining the issue, logs, and history.

Result: the application contains no corporate defaults; the connection owner configures the quick workflow.

## 6. Traceability

| Area | Main evidence |
|---|---|
| Stories US-H01–US-H12 | Acceptance scenarios A01–A19, E2E-05, and related `flutter_test` tests from section 12 of the MVP specification. |
| Basic API discovery | `test/agent_api_server_test.dart`, `test/agent_api_integration_and_ui_test.dart`. |
| Log CRUD, search, and day planning | A20–A24, `test/agent_api_endpoints_test.dart`. |
| Managing quick issues through the API | A26, `test/quick_issues_test.dart`. |
| Jira issue card, comments, and attachments | A25, US-A10, `test/agent_api_issue_details_test.dart`. |
| Splitting, merging, and fixed start | `test/agent_api_split_merge_test.dart`. |
| Final Jira submission | UI/AppState/WorklogSender only; the Local Agent API has no such endpoint. |
