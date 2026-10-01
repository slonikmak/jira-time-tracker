# Jira Time Tracker — MVP implementation specification

Date: 2026-09-14. Product behavior was agreed with the user after an interview.
The Jira address is user-configurable. Platforms: Flutter Desktop, Windows and macOS. The [release guide](../releases.md) defines builds and delivery.

## 1. Assignment for the implementer

Implement a working local application from this specification. It contains sufficient context to work without conversation history. Complete the stages in section 13 in order; finishing the first stage does not complete the assignment.

Project rules: [AGENTS.md](../../AGENTS.md). User value and end-to-end human/agent workflows: [user stories](user-stories.md). Modules and storage: [ARCHITECTURE.md](../../ARCHITECTURE.md). Screens, forms, and interactive design: [UX/UI](../design/UX.md). These files form the assignment package; this specification owns requirements and acceptance criteria.

Sections 2–3 define the agreed product core; sections 4–8 describe workflows. Draft associations, splitting thresholds, post-submission behavior, time zones, and storage structure are engineering defaults in this specification rather than separate user requests. Sections 9–13 define implementation and verification. Preserve the product contract when adapting technical details to the installed SDK.

Before changing anything, read applicable AGENTS.md files and inspect the tree and tools. When this document was prepared, the directory contained only support folders and skills-lock.json; there was no Flutter project or Git repository. Flutter and Dart commands were available. Recheck actual state, which may have changed.

Deliver the application, section 12 checks, a Windows release build, and a README covering startup, configuration, and limitations. Preserve existing user files. Real credentials are unnecessary for implementation or verification with a fake Jira API.

## 2. Why the application exists

The user works on several Jira issues in parallel, including through agents. They need independent local time records and a way to choose which records to submit to Jira at the end of the day.

Primary workflow:

**Jira issue → local logs → select logs and date → build day → manual edits → submit to Jira.**

Day building may increase or decrease original durations, move logs to another date, and split them into intervals. This behavior was deliberately agreed. Original durations remain in local history; the build result is stored separately.

### MVP scope

- One active Jira account, local data, Windows and macOS desktop.
- Theme options in Settings: **System default** (default), **Light**, and **Dark**. Apply immediately and persist between launches.
- Switch the interface between Russian and English; selection and upgrade rules are in section 8.2.
- Integrate through standard Jira Cloud worklogs. Separate Planim integration is out of scope; display of entries specifically in Planim has not been verified.
- Users select issues. There is no application-level assigned-to-me restriction; Jira permissions apply.
- Status filtering, automatic hiding of closed issues, AI-generated descriptions, cloud sync, mobile versions, tray behavior, autostart, and an installer are outside the MVP.
- Create new worklogs; edit and delete existing Jira worklogs outside the application.

## 3. Terms and invariants

| Term | Meaning |
|---|---|
| Issue | A Jira issue identified by issueId and key, with a summary. |
| Quick issue | A user-saved reference to an existing issue within a specific Jira site/account for repeated selection; not a separate Jira issue type. |
| Local log | An original work fact for one issue, with duration and optional description, created by a timer, manual entry, or Local Agent API. |
| Day draft | A saved placement of selected logs on a selected date, editable before submission. |
| Source binding | The association of one local log with one draft, including a snapshot of its full original duration and description. |
| Interval | A representation of part of a local log in a draft: source reference, issue, start, duration, and description. After submission, corresponds to one Jira worklog. |
| Break | Time within the working day that is not submitted to Jira. All breaks have equal status; lunch is no longer a separate entity. |
| Consumed log | A log whose remaining draft intervals have all been successfully submitted; not offered for another build. |

- Select **logs, not issues**, for a build. Several logs for one issue remain separate logs.
- The association runs from a source log to a day: one local log may produce one or more intervals in one draft, with exactly one source binding. Their total may differ from the original duration retained in the snapshot.
- Every interval references exactly one source log. Splitting an interval within a day does not create a new log; only parts of the same source may be merged into one interval.
- A local log cannot belong to drafts on different dates simultaneously. To place parts on different days, first split a free log into independent LocalLogs in the queue.
- Three timers running for an hour produce three one-hour local logs. Their sum does not automatically become the day duration.
- The full day span, including breaks, has no artificial eight-hour limit and must stay within a calendar day. Parallel worklog durations may sum to more than that span.
- Work intervals may overlap each other and existing Jira worklogs; each remains an independent entry. Breaks cannot overlap work or each other. The default automatic builder still places new intervals into free slots.
- Successful submission consumes a whole log. Reducing 2:00 to 1:20 does not leave 40 minutes for another day.
- Generating and editing a draft submits nothing to Jira.
- Source logs are not consumed before submission results are confirmed.

## 4. Issues and local logs

### 4.1. Recent issues

The add field accepts a key such as PROJ-123, a numeric Jira issue ID, or a URL on this Jira site, such as /browse/PROJ-123. Retrieve the summary and canonical key from Jira. Adding the same issue again shows its existing row and moves it up the list.

Sort by last interaction: adding, starting, pausing, or manually logging time. Keep previously used issues. Minimum navigation: key/summary search and, for a large list, **7 days / 30 days / All** recency filtering. Filters affect list visibility only, not log availability or persistence.

Each row shows the key, Jira status, and summary. Provide **Start timer / Stop timer** and an adjacent **Add time manually** action. Selecting multiple rows and **Start selected** starts their timers together.

### 4.2. Timer (Start / Stop model)

- **Start (Play)** always creates a separate new entry at zero (00:00:00). The redundant **New log** button is incorporated into Play.
- **Stop** stops the timer, saves accumulated duration to the queue, and detaches the log from its issue card. The card's counter resets to 00:00:00, ready for another start.
- Timers on different issues are independent. One current timer may run per issue in the MVP; starting an already-running timer does not create another.
- Closing the window, terminating the process, sleeping, or restarting Windows does not stop an active timer. Reopening includes the elapsed period.
- Only stopped logs with positive durations may be built into a day. Show a stop action for running logs.

### 4.3. Manual entry — required primary workflow

**Select issue → Add time → three hours → optional description → save.**

Create a separate stopped log of 10,800 seconds. No timer is needed; manual entry does not affect timers running on this or other issues. Use separate hour and minute fields and validate a positive total. Descriptions may be empty.

Stopped logs not yet in a draft can have their duration/description corrected or be deleted. Once bound to a draft, edit there or exclude the log first.

### 4.4. Summary and description

A log's title is the Jira summary retrieved when it was created. Its description is user-authored text about work done. These are different values; the application does not change Jira issue summaries.

Splitting a log copies its description into every interval. Each draft part's description can then be edited independently. Empty descriptions are allowed; do not insert placeholders such as **Worked on the issue** automatically.

### 4.5. Splitting and merging sources

A free stopped log can be split into two positive logs or merged with other free logs. These operations change source facts, allowing parts to be independently placed on different days. Running, consumed, or draft-bound logs cannot be changed this way. Splitting and merging intervals on Day is a different operation: it changes only one source's representation within one day.

### 4.6. Quick issues

There is no built-in company issue list. Users maintain a quick-issue catalog separately for each Jira site/account. New and upgraded installations start with empty catalogs.

Add by key, numeric ID, or URL. Before saving, retrieve canonical issueId, key, and summary from Jira. Network failures or unknown issues must not produce synthetic local records. An optional local purpose note is allowed. Display insertion order; manual sorting, categories, and disabling are unnecessary.

Deleting a quick issue removes only its reference. Cached Issue, LocalLog, DayDraft, Segment, and history remain unchanged. Without an active verified connection, the catalog cannot be modified. On Work, an empty quick-issue menu opens its Settings section; selecting a configured issue opens manual time entry with that issue selected.

## 5. Queue and log consumption

The main list shows unused logs with issue, original duration, creation date, and description. Creation dates do not restrict submission dates: a Friday log can be selected for Monday.

Consumed entries remain in local history with submission date and resulting Jira worklog IDs. They are not offered for rebuilding. Unselected entries stay in the queue without being moved or reduced.

Draft rule: keep one unfinished draft per date; a local log belongs to one draft at a time. Binding alone does not consume it. Before first submission, remove a log and select it for another date. Once submission starts, retain the association until all results are resolved.

Removing all intervals of a log from a never-submitted draft returns it to the queue. Removing only some intervals still consumes the whole source when the remaining intervals are sent.

## 6. Day building

### 6.1. Default settings

| Setting | Value |
|---|---|
| Day start | Random time from 08:00 to 09:00 inclusive |
| Full duration | 7 h 30 min to 8 h inclusive |
| Long break start | 12:00 to 14:00 inclusive |
| Long break duration | 30–45 minutes inclusive |
| Short breaks | 2–4 per day |
| Short break duration | 5–10 minutes inclusive |
| Minimum work interval | 15 minutes |

Settings are editable and persistent. Validate min <= max, valid times of day, and positive durations. A 0–0 long-break duration disables it; mixed 0–N ranges are invalid. Ranges govern generation; manual edits may exceed them while respecting date boundaries and keeping breaks outside work.

Ranges are application-wide on this computer and independent of the Jira connection. Additional short breaks may number 0–95, a defensive bound based on 24 hours and the minimum work interval. Mandatory breaks between adjacent generated intervals remain and use the minimum configured short-break duration. The builder respects long-break start ranges and short-break counts even on short days. If placement is impossible, return an error and retain the previous draft. **Reset** changes form values only; they apply after **Save settings**.

Saving settings does not change the open draft. Both explicit algorithmic commands, **Smart rebuild** and **Rebuild day** preserving order, use current saved ranges and update the draft's settings snapshot after a successful rebuild. Opening a draft does not replace application-wide settings with its snapshot. As-recorded building preserves original log times and durations under section 6.3.1.

In Day build, users also edit a text rule telling an AI agent how to apply these ranges. Store it on this computer with the ranges, independently of Jira scope. It does not change the built-in builder. Do not save an empty rule. **Reset** restores both ranges and the original rule to the form. Before every build, the agent retrieves current ranges and rule in one `GET /api/day-settings` request.

Arithmetic example: 08:34–16:22 spans 7:48. A 35-minute long break and two eight-minute short breaks total at least 51 minutes. With an existing one-hour worklog, 5:57 is the maximum new-work budget before mandatory inter-interval breaks; actual new time may be lower.

### 6.2. Inputs and outputs

Inputs: selected date, stopped logs, duration-lock flags, settings, existing Jira entries, and random seed.

Outputs: day boundaries, breaks, new intervals, original/resulting totals per log, and overall totals. Do not overwrite sources. Identical inputs and seed produce identical results; **Rebuild** uses a new seed. Opening a saved draft does not regenerate it.

### 6.3. Day-building modes

Support default as-recorded building and smart algorithmic rebuilding.

#### 6.3.1. Default as-recorded build

Invoked by **Build day** on Work:

1. Transfer selected logs to the timeline at their original local times, preserving durations. Do not split issues or add artificial breaks; retain natural gaps.
2. Timer logs use their actual `originalStartUtc` .. `originalEndUtc`. Manual logs start at `createdAtUtc - duration` and end at `createdAtUtc`.
3. Project local times from other dates onto the selected build date.
4. Resolve overlaps with parallel logs or existing Jira entries by ordering logs by start time. If an interval overlaps an occupied slot, cascade it forward to the first free second without losing duration.
5. Stay within calendar-day boundaries, up to 23:59:59.

#### 6.3.2. Algorithmic build (Smart rebuild)

Invoked by **Smart rebuild** on Day:

1. Validate inputs and retrieve existing Jira entries for the selected date under section 10.2. A read failure is not an empty day.
2. Choose a window within configured ranges that accommodates existing intervals. Treat them as occupied and immutable.
3. Short days: if source logs total less than six hours, do not stretch to eight. Cap the work budget at the source total and tighten boundaries around placed work. Omit the long break if work totals less than four hours.
4. Place a long break for work lasting $\ge 4$ hours and short breaks in free time. Breaks must not overlap occupied work or each other. Leave work between adjacent breaks.
5. Subtract existing intervals and breaks from the day window. The remaining slots form the new-log budget. Subtract locked durations first, then distribute the remainder among unlocked logs proportionally to their original durations in seconds.
6. Do not split issues lasting up to 60 minutes inclusive. Split longer issues into 30–60-minute parts. Generated work intervals must last at least 15 minutes; redistribute shorter remainders. Part totals must exactly match the log's allocated duration.
7. Place parts sequentially in free slots. Require a short break between every pair of adjacent new work intervals. Preserve the relative order of different logs for the same issue.
8. Validate section 3 invariants and save in one transaction.

A duration lock means the builder retains that log's total duration. Smart rebuild may split it into intervals. Subsequent manual duration changes remain allowed.

Randomness affects scheduling, breaks, and splitting, never work descriptions or log selection. Use an ordinary local algorithm without LLMs or paid APIs.

If locked durations do not fit, all logs are locked but do not fill the budget, or breaks cannot be placed, explain the specific cause and suggest adjusting selection, locks, or settings. Never silently omit selected logs. Bounded search for placement is allowed. On failure, preserve the previous draft and return a clear error rather than entering an infinite random loop.

## 7. Editing and submission

A draft is a time-sorted interval table: issue, start, computed end, duration, description, and submission status. Show breaks between rows. Existing Jira worklogs are visually distinguished and read-only.

Allow editing date and day boundaries, and new-interval starts, durations, and descriptions; intervals can be deleted, split, or merged. Merge only intervals of the same source to retain provenance. Update totals and errors immediately. Mouse dragging is not required. Changing the date loads existing entries directly from Jira regardless of whether a local draft exists; removing the last local interval does not hide them. Random generation must not replace manual edits.

Changing an interval's start or duration shifts subsequent new intervals and planned breaks by the change in its end time, preserving their durations and gaps. Locked intervals and intervals whose submission has started cannot move; if an edit requires this, show an error and retain the previous draft. Existing Jira entries remain unchanged; new intervals may overlap them. Description-only edits do not change time. Rebuilding retains each selected source's original duration for comparison and does not double-count its parts.

Before submission, show full day duration, breaks, and Jira time (existing + new). Nonpositive durations, intervals outside the date, breaks overlapping work, or existing-entry read failures block submission while keeping an editable draft. Show work overlaps without blocking. Day spans above eight hours are informational and do not block submission.

**Rebuild** explicitly replaces a never-submitted draft. Ordinary field edits do not rebuild it. After the first submission attempt, date and part composition are fixed: finish that plan instead of generating another over it.

**Clear** on Day asks for confirmation and deletes the selected date's entire never-submitted draft: intervals, breaks, and source bindings. Source LocalLogs return to the free queue; existing Jira worklogs stay unchanged and visible. Disable clearing in read-only mode and after submission starts.

**Submit to Jira** is a separate action. A repeated click during submission does not start another submission. Show results per interval; consume a source only after all its remaining parts are confirmed. Partial success and unknown results must follow section 10.3.

## 8. Connection and interface simplicity

Connection fields: JIRA_BASE_URL, JIRA_EMAIL, JIRA_TOKEN. For this user, the default base URL is https://esprowteam.atlassian.net; this is a default, not a hardcoded HTTP-client restriction.

When opening Settings, populate unsaved fields from corresponding process environment variables. Users edit and save the form; saved values take precedence on subsequent openings. Saving requires a complete valid set. Clearing a required field must not silently reuse an old secret. Cancel preserves the previous connection. No separate source selector is needed.

**Check connection** tests the current form and shows the account or a clear error. Mask tokens and store credentials in Windows Credential Manager or macOS Keychain, outside SQLite, README, logs, and sources.

Minimum layout: Work and Day tabs, a separate Settings button, and Add time dialog. Work has recent issues on the left, log queue on the right, and history within the screen. Settings has a pinned language/theme header, Jira connection / Day build / Quick issues / Local API navigation, and one active content area. There is no General section or global Save button; each section saves by its own explicit rule. [UX/UI](../design/UX.md) owns layout and state presentation. Use standard Flutter Material widgets with section 8.2 localized labels and clear messages for technical submission states.

Cached issues, timers, manual logs, and saved drafts work offline. Adding unfamiliar issues, fresh Jira-aware builds, and submission require connectivity. Network failures preserve local data.

### 8.1. Local Agent API

The local API is another interface to the same entities and rules, not a separate store. Agents can search known issues, filter the queue by text/key/state, and create, edit, delete, split, or merge free LocalLogs. Mutations for an unknown key must successfully retrieve the issue from Jira; network failures must not invent a local issue.

`GET /api/quick-issues` returns only the active Jira scope's references in insertion order: issue ID, key, summary, and optional local `note`. `POST /api/quick-issues` accepts `issue_key` (key, ID, or URL) and optional `note`, validates through Jira, and adds the reference. Repeated requests retain position; a supplied `note` updates the description. `PATCH /api/quick-issues/{issueId}` updates or clears `note`; `DELETE /api/quick-issues/{issueId}` removes only the reference, retaining issues, logs, and history. Reject mutations without an active connection or in read-only mode. The old `/api/service-tickets` company endpoint is absent; the quick catalog does not restrict normal use of verified issues.

`GET /api/issues/{issueKey}/worklogs` reads all accessible worklogs under the current connection with complete pagination and no selected-date restriction. Return issue key/ID and entries with `author_account_id`, start, duration, description, and `is_mine` for the current accountId. Network failures are not empty lists; the route submits nothing to Jira.

`GET /api/issues/{issueKey}` reads current fields: key/ID, summary, plain-text description, status, type, priority, assignee, labels, and dates. Retrieve all accessible comments with pagination and return author, dates, and text. Attachment metadata includes ID, filename, MIME type, size, date, author, and relative `download_path`, without file contents or token-bearing Jira URLs. `GET /api/issues/{issueKey}/attachments/{attachmentId}` downloads binary content only after verifying the ID in that issue's attachment list. Jira errors are not empty comments or files. Both routes read Jira only and create no local files. [Issues](https://developer.atlassian.com/cloud/jira/platform/rest/v3/api-group-issues/), [comments](https://developer.atlassian.com/cloud/jira/platform/rest/v3/api-group-issue-comments/), [attachments](https://developer.atlassian.com/cloud/jira/platform/rest/v3/api-group-issue-attachments/).

The server accepts only loopback Host values and rejects foreign Origins. A direct `http://127.0.0.1:<port>` address suffices for agents; no separate session is required.

`GET /api/day?date=YYYY-MM-DD` loads ExistingWorklogs for the requested local date and returns them with its DayDraft and deterministic `revision`. Jira failures are request errors, not empty days or data for the date currently open in the UI.

`GET /api/day-settings` returns current numeric `settings` (`DaySettings.toMap` keys) and editable text `rule` in one JSON response, without a Jira request. Agents read both before every build and apply both to the snapshot. Text previously copied into agent instructions is not the source of current rules.

`POST /api/day` atomically saves a complete Agent Day Snapshot instead of interval commands. Each Segment requires the `source_log_id` of an existing stopped, unused LocalLog; the source determines its issue. Several Segments may share a source, with one DraftLog snapshot of its full original duration. Work Segments may overlap each other and Jira worklogs; compute breaks outside their union. Do not replace a source bound to another active draft or a partially submitted draft. Replacing an existing draft requires `base_revision` from the latest read. Mismatches, including after user deletion, return conflict without partial writes. Segment split/merge API commands are unnecessary; agents send complete snapshots. Final Jira submission remains an explicit UI action.

### 8.2. Interface language

Language is application-wide on this device, independently of Jira connection. Options are System default, Russian, and English; language names always use their native spellings. Apply immediately without restart and persist locally. Disable language changes in read-only mode, as for theme changes.

New installations start in system mode: a Russian OS language selects Russian UI; English and all other languages select English. Locale region does not affect this rule. An existing installation without a language setting retains Russian after upgrade, including installations without logs or issues. Manual selection overrides system language. System mode responds to platform locale-change notifications and picks up the new language on the next launch.

Translate application-owned labels on all screens/forms, hints, empty states, confirmations, warnings, messages, errors, calendars, and standard dialogs. Month/weekday names and duration units follow the chosen language. Numeric dates keep day–month–year order (`30.09.2026`), and time stays in 24-hour format (`14:05`), including date and time pickers. Switching does not change time zones or date/duration values.

The Local API agent instruction, its clipboard copy, and `GET /api/help` follow the current UI language. The standard Day build rule also switches language, including previously saved unchanged default text. **Reset** restores the standard rule in the current language. Saving a standard rule does not pin its text language; `GET /api/day-settings` returns it in the current UI language. If the user edits the rule, switching languages preserves their text, including unsaved edits and edits retained after restart.

Never automatically translate the Jira Time Tracker name, keys/identifiers, Jira summaries/statuses, worklog text, user descriptions, local notes, or user-edited agent instructions. Jira error text and old saved errors remain in their original form. New application-owned errors support both languages, including after persistence and restart.

Switching preserves navigation, entered fields, selected date/logs, timers, LocalLogs, DayDrafts, and submission results. Switching alone submits no worklogs and does not change the Local Agent API contract. Persistence failure shows an error and retains the previous language. [UX/UI](../design/UX.md) owns the selector's appearance and placement.

## 9. Minimal technical structure

[ARCHITECTURE.md](../../ARCHITECTURE.md) is canonical: sections 1–2 define stack/modules, section 3 entities/transactions, section 4 time representation, and sections 5–6 execution flows and testing interfaces. Read it before implementation; technical details are maintained there in one place.

## 10. Jira Cloud integration contract

Public documentation was checked on 2026-09-14. Real account access, permissions, and API tokens were not yet verified. Before using the API, check request formats against the primary sources below.

### 10.1. Authentication and operations

Email + API token use Basic Auth. Ordinary tokens use the Jira site API; scoped tokens use https://api.atlassian.com/ex/jira/{cloudId}. [Authentication](https://developer.atlassian.com/cloud/jira/platform/basic-auth-for-rest-apis/), [token types](https://support.atlassian.com/atlassian-account/docs/manage-api-tokens-for-your-atlassian-account/).

Retain the three UI fields. Connection testing first tries GET /rest/api/3/myself on the site; after authentication rejection, try the scoped-token route. Retrieve cloudId without credentials from /_edge/tenant_info. Persist the working route with the connection. If both routes fail, show an error; token format/length is not a reliable type indicator. [Retrieving cloudId](https://support.atlassian.com/jira/kb/retrieve-my-atlassian-sites-cloud-id/).

Use HTTPS, standard certificate validation, and only the configured origin or fixed Atlassian gateway. Parse issue URLs as data; send credentials to the configured API, not arbitrary input URLs. Credential-bearing redirects to another origin are forbidden.

| Operation | API path relative to the chosen route |
|---|---|
| Account | GET /rest/api/3/myself |
| Issue | GET /rest/api/3/issue/{idOrKey}?fields=summary |
| Details and attachments | GET /rest/api/3/issue/{idOrKey}?fields=summary,description,status,issuetype,priority,assignee,labels,created,updated,attachment; GET /rest/api/3/attachment/content/{id}?redirect=false |
| Comments | GET /rest/api/3/issue/{idOrKey}/comment; startAt/maxResults pagination |
| Search issues with worklogs | POST /rest/api/3/search/jql; nextPageToken pagination |
| Issue worklogs | GET /rest/api/3/issue/{idOrKey}/worklog; startAt/maxResults pagination |
| Create interval | POST /rest/api/3/issue/{idOrKey}/worklog?adjustEstimate=leave |

Creating worklogs requires Browse projects and Work on issues permissions, not assignment to the author. Send started, timeSpentSeconds, optional ADF comment, and a reconciliation property. Worklogs have no separate title/end/pause fields. Titles stay local; comments contain descriptions. adjustEstimate=leave preserves remaining estimate. [Worklogs API](https://developer.atlassian.com/cloud/jira/platform/rest/v3/api-group-issue-worklogs/).

For nonempty descriptions, use ADF doc version 1 with paragraphs/text nodes and preserve line breaks. Omit comment for empty descriptions. Exclude secrets and internal IDs from user comments.

### 10.2. Existing day

Identify the current user by accountId, not email/displayName. Opening a date loads existing worklogs directly from Jira even without a local draft. Search candidate issues using worklogAuthor/accountId and worklogDate with a one-day margin on each side. Then retrieve every worklog page and filter by accountId and actual timestamps. JQL selects issues, not individual entries, so exact filtering remains necessary. The margin compensates for JQL/Windows time-zone differences. Also check cached and selected issues. Complete pagination and exact filtering are mandatory. [Search](https://developer.atlassian.com/cloud/jira/platform/rest/v3/api-group-issue-search/).

Occupied time is [started, started + timeSpentSeconds). Include entries intersecting the selected local day; show entries crossing its boundaries as automatic-build conflicts. This is computed occupancy, not a statement about Planim's internal timers.

JQL worklogDate covers the latest 1,000 worklogs per issue; APIs expose only entries accessible to the user. This does not guarantee complete old history. Document the limitation in README. Show incomplete loading and errors in the UI; successful empty results and failed loading are distinct states. [JQL limitation](https://support.atlassian.com/jira-software-cloud/docs/jql-fields/).

Existing worklogs may overlap each other and the new plan; never modify them automatically. A free-slot automatic build may report impossible placement. Immediately before submission, refresh existing entries and verify data availability, date boundaries, and breaks. If the external day changed, retain the draft and show conflict. Recognize already-confirmed own intervals by worklogId to avoid double-counting.

### 10.3. Partial submission and duplicate protection

Interval states: pending → sending → sent / failed / unknown. failed means confirmed rejection without creation; unknown means the request may have been accepted without a received confirmation. Persist this distinction in SQLite.

1. Before POST, save immutable interval ID and submitted fields, then sending. POST sequentially, one interval at a time.
2. In that POST, send property jira-time-tracker.segment with value {id: <segment UUID>}, enabling reconciliation after response interruption. Jira supports worklog properties; see [Worklog properties API](https://developer.atlassian.com/cloud/jira/platform/rest/v3/api-group-issue-worklog-properties/) for reads.
3. After HTTP 201 and a valid worklogId, immediately persist sent and the ID transactionally. Retries skip sent intervals.
4. After confirmed rejection, persist failed and a clear reason. Timeouts, interrupted responses, invalid success responses, and ambiguous server errors produce unknown. Leftover sending after restart also becomes unknown.
5. For unknown, offer **Check result**. Load the issue's worklogs with pagination and find the saved property. For one match, compare author, date, duration, and description. A full match becomes sent; mismatches or multiple matches require manual conflict resolution.
6. One read without a match does not prove POST rejection. Never automatically resend unknown or offer its source for rebuilding. Explain the need for another reconciliation. This is an MVP limitation, not server-side idempotency.
7. Allow manual resolution: **Enter existing worklog ID**, validating issue, author, and fields, or **I checked Jira; the entry does not exist — allow retry**. The latter requires completed network attempts and explicit confirmation. Return to pending while preserving ID and recording the manual decision. Do not present manual confirmation as an API guarantee of absence.
8. **Retry submission** sends only pending and corrected failed intervals. Consume a source only once all its intervals are sent. A fully successful source does not wait for recovery of other sources' errors.

After the first POST, draft composition is immutable. For known failures, users may fix credentials/access and retry the same plan. Moving a partially submitted day or editing sent worklogs requires manual Jira use; a rollback workflow is outside the MVP.

## 11. Required errors and messages

| Situation | Behavior |
|---|---|
| Invalid ID/URL or inaccessible issue | Explain the cause; do not create a fictitious issue. |
| Zero or negative time | Do not save a completed manual log or include it in a day. An empty timer before starting is allowed. |
| Running timer selected for a build | Offer pause; do not silently snapshot a changing duration. |
| Locked logs do not fit | Show required and available hours. |
| Jira-day loading failure | Preserve local data; do not build or submit assuming an empty day. |
| Wrong draft account/site | Block submission and show the required connection. |
| 401/403, forbidden worklogs, 429 | Show the error; honor Retry-After for 429 without infinite retries. |
| Partial success | Show each row's result and retain confirmed entries. |
| Unknown POST result | Reconcile the property under section 10.3, without blind retry. |
| Disk persistence failure | Do not report successful saving/completion; retain a recovery path. |

## 12. Acceptance scenarios

Verify business logic through flutter_test and a fake HTTP client, using temporary SQLite databases. Pass current time and seed explicitly. Do not build a separate testing platform.

| ID | Scenario | Expected result |
|---|---|---|
| A01 | Manual three hours, no description or Play | One stopped 10,800-second log; no Jira POST. |
| A02 | Three issues run simultaneously for one hour | Three independent 3,600-second logs. |
| A03 | Play → pause → Play; close and reopen | One resumable log; pause time excluded, closed/sleep time included; persistence survives restart. |
| A04 | New log, manual entry with a running timer, Play after draft binding | Section 4 holds; another timer is neither overwritten nor duplicated; draft snapshot does not become a running timer. |
| A05 | Add the same issue assigned to someone else by ID and URL | One issue row; no assignee restriction. |
| A06 | Build with several fixed seeds | All selected logs represented; new intervals >= 15 minutes with breaks between neighbors; exact totals, unchanged sources, day <= 8 h, no overlaps. |
| A07 | The arithmetic example includes an existing hour | Full day 7:48, breaks 0:51, new work 5:57, Jira total 6:57. |
| A08 | Lock one log; insufficient budget | Preserve its total; impossible builds fail without omitting logs or corrupting the previous draft. |
| A09 | Split a large log | Parts reference one source; totals match; copied descriptions can be edited independently. |
| A10 | Original 2:00 submitted as 1:20 | Consume the whole source; no 0:40 remains in the queue. |
| A11 | An unselected log from last week | Available for another date; issue-list filtering does not delete it. |
| A12 | Multiple search/worklog pages and different authors | Process all pages; select only the requested accountId/day. A failed page is not an empty result. |
| A13 | Manual edits, deletion, date change | Update totals/conflicts; load existing entries for the new date; no random rebuild. |
| A14 | Interval 1 sent, interval 2 failed; repeat click/restart | Never resend interval 1. Consume its source after all parts are confirmed. |
| A15 | Jira creates a worklog but its response is lost | unknown; property reconciliation restores sent without another POST. Missing property does not permit blind retry; manual resolution requires an explicit user action. |
| A16 | Environment values, manual changes, reopening | Environment populates the form; saved input wins; Cancel retains settings; token absent from database/logs. |
| A17 | Ordinary/scoped route and account switch | Test both routes read-only; do not send old drafts under another account/site. |
| A18 | Different UTC offset and near-midnight worklog | Correct local date, no persistence/reopening shift, correct boundary checks. |
| A19 | Another process and crash after sending | Second instance neither writes nor submits; unfinished sending recovers as unknown. |
| A20 | Local Agent API issue search, queue filtering, Jira issue history | Search local keys/summaries; logs expose `free`, `running`, or `in_draft` and draft date; history reads all accessible pages and identifies current-account entries; filters preserve data. |
| A21 | Agent sends two intervals for one `source_log_id` and parallel work | One DraftLog retains full source duration; two Segments reference it and become two worklogs; work overlaps stay unshifted, breaks exclude work; LocalLog unchanged. |
| A22 | Place one work fact on two dates | First split its free LocalLog into independent sources, each bound only to its own DayDraft. |
| A23 | Agent reads a date, UI edits, agent saves stale snapshot | Load ExistingWorklogs for the requested date; stale `base_revision` conflicts without damaging the prior draft. |
| A24 | Invalid source, another date, or merge of different sources | Reject the whole operation without partial writes; do not merge different LocalLogs' intervals; no Jira POST. |
| A25 | Agent reads paginated comments and downloads an attachment | Return all accessible plain-text comments and metadata; download separately by this issue's attachment ID only; page errors, foreign Origin/Host, or token-bearing redirects cannot yield false success. |
| A26 | Agent adds, edits, and removes a quick issue with note | GET is active-scope insertion order with summary/note; POST verifies Jira without offline fallback; PATCH changes note; DELETE retains Issue/LocalLog; other scopes unaffected. |
| A27 | Clear an unsubmitted day with multiple intervals | Confirmation removes draft/breaks, releases sources to the queue, and leaves Jira worklogs unchanged; clearing blocked after submission starts. |
| A28 | Change ranges/rule, then agent starts a build | One `GET /api/day-settings` returns new ranges/rule; persist across restart; agent instructions require reading them before every build. |
| A29 | New/existing installation, language choice, OS-language change, restart | Section 8.2 holds; translate screens/own messages, retain forms/timers/selection/draft; failed persistence/read-only retain language; unambiguous dates/time; no Jira POST. |

Minimum manual Windows UI check: add an issue through a fake API, create manual and timer logs, build a day, edit an interval, restart and verify persistence, then submit through a fake API with partial rejection.

Use a fake API for development and automated checks; never create test worklogs in production Jira. Live submission is a user action after draft review. If no real connection was used, say so in the report rather than claiming verification on the user's account.

## 13. Implementation stages and completion

| Stage | Work | Completion criterion |
|---|---|---|
| 1. Foundation | Run flutter doctor -v; create the Windows project here while retaining support files; prepare UI and SQLite/secure storage. | Application opens; a test local entry and settings survive restart. |
| 2. Issues and logs | Jira client, connection, recent issues, parallel timers, manual logs. | A01–A05 and A16 work; the complete manual-entry workflow is usable. |
| 3. Builder | Pure build function, settings, duration locks, splitting, draft persistence/editor. | A06–A11 and A13 pass; builds accept known input worklogs. |
| 4. Jira day, Local Agent API, submission | Existing entries, agent day snapshots, pagination, boundary validation, POST journal, unknown reconciliation. | A12 and A14–A24 pass with a fake API; retries do not duplicate confirmed entries. |
| 5. Delivery | Verify Windows UI, README, and release build. | Run the commands below and provide a short report and build path. |

Final verification commands once sources exist:

```powershell
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
flutter build windows --release
```

Before final verification, fix formatting with dart format lib test. A web page, screenshot, or single UI demonstration does not replace a desktop build.

README must cover Windows startup, entering/populating the three connection fields, data paths, timer behavior while closed, older-worklog search limits, and unknown recovery. Deliver the complete release bundle, including required libraries and data, rather than just an exe.

Report implemented stages, command results, build path, whether a live read-only smoke check was performed, and remaining real-Jira checks. If the environment cannot build Windows, name the missing component, finish sources and available checks, and explicitly mark the build incomplete.
