# Jira Time Tracker UX/UI

Date: 2026-09-25. Description of the implemented Flutter Desktop interface for Windows.

## How to use this document

1. Read this document before implementing screens and forms.
2. Inspect pages 01–08 of the [Pencil mockup](../../astra.pen) through Pencil MCP. They define the current visual style: light and dark palettes, flat surfaces, thin dividers, and layout. Page “01 · Work — compact” defines the scale of the entire interface: its 1152×800 size is 80% of the original 1440×1000 page. Fonts, fields, buttons, icons, dividers, spacing, and dialogs on all screens scale by the same factor. Page 07 shows dialog and state variants, not a separate application screen.
3. Implement the interface with Flutter Material 3 within the [architecture](../../ARCHITECTURE.md). Preserve actual features and states of the current application, including those absent from Pencil: the mockup does not define a new product contract and contains sample data.
4. Verify behavior against the [MVP specification](../specs/jira-time-tracker-mvp.md), including A01–A24. It defines time, storage, and submission rules; this document defines navigation, layout, and state presentation.

The earlier [interactive HTML mockup](jira-time-tracker-ux.html) and its [fragment](jira-time-tracker-ux.fragment.html) remain references for the original scenarios. Use Pencil pages 01–08 for the current appearance.

## Navigation and visual approach

The two main tabs are **Work** and **Day**. The application name, “Jira Time Tracker,” precedes the tabs in the top bar; **Settings** is on the right, with a connection indicator beside it when Jira is connected. Settings opens as a separate page in the same shell; returning to Work or Day closes it. Manual time entry and record editing open dialogs over the current screen. Application messages appear below the top bar and can be dismissed.

Work primarily uses two columns separated by a thin vertical divider: recent issues on the left and the log queue or history on the right. An issue row contains its key, available Jira status, title, last activity time, current timer, and Start/Stop and Add time actions. Below an area width of 1125 px, columns become vertically stacked with separately scrollable content. The original “Logs first” and “Grouped by issue” alternatives served design discussion; the UI has no layout or density selector.

The interface is calm and compact: Inter font, thin dividers, and a small color accent for the primary action. Timers and durations use IBM Plex Mono. By default the theme follows the system; the user can select light or dark manually in Settings. The dark palette comes from Pencil page “08 · Work — dark theme” and uses the same 80% scale: background `#1B1E25`, inset areas `#15181E`, dividers `#323844`, selection `#252E4B`, primary text `#ECEEF3`, secondary text `#A1AABA`, links and active controls `#97AAFF`, and primary button `#758EFA` with text `#10182F`. States differ by text and icon as well as color.

Use standard Flutter controls with clear focus and keyboard operation. Action icons have tooltips. When another instance holds the write lock, a read-only warning appears below the top bar and data-changing actions are disabled. In narrow windows, Work, Day, and Settings rearrange vertically with scrolling. Window-control buttons shown in the mockup are decorative; the application uses a normal Windows window.

## Work screen

| Area | Content and actions |
|---|---|
| Header | Work heading, selected date, and global Add time button. Below are a field prompting for a Jira issue ID or link, Add issue button (also triggered by Enter), and Quick issues menu. A configured entry shows key, Jira summary, and an optional local hint; selecting it immediately opens manual time entry. An empty menu offers Configure quick issues. |
| Left column | Recent issues: key, Jira status at the right edge when available, title, last activity time, timer, and Start/Stop and Add time actions. Search and Last 7 days / Last 30 days / All time activity filters affect only the issue list. The empty state suggests adding an issue or changing the filter. |
| Issue selection | Select multiple mode shows issue checkboxes; after selection, Start (N) becomes available. Starting creates independent timers for the selected issues. Cancel exits the mode and clears selection. |
| Right column | Queue and History tabs show entry counts. The queue also shows total duration and, when timers are running, a pause-all button. History groups logs by the date they were consumed; it contains entries already used in a submitted day. |
| Running log | Shows issue key, live duration, title, description, creation date, and a warning to stop the timer. The selection checkbox is unavailable; a separate button pauses that timer. |
| Free stopped log | Build checkbox, duration/description editing, and deletion. Manual and timer logs have equal standing. A log in an unsubmitted draft for the selected date remains checked: unchecking removes all its intervals from the draft and returns it to the queue. A log in another date's draft has no checkbox: instead it shows a calendar icon, persistent “In day DD.MM.YYYY · Open” label, and, before submission starts, a separate “Remove from day DD.MM.YYYY” action. Once submission starts, day membership cannot change. |
| Queue footer | Count of logs selected for the date, total source time, calendar date selection, and Build day button. The button is enabled when something is selected; it builds a draft and opens Day. With no selection, the bar explicitly states that no entries are selected for the chosen day/month. In History, a notice that history is stored on this device replaces the selection bar. |

Selecting an issue to start a timer and selecting a log to build a day are distinct actions in different columns. One issue can have several entries with different descriptions. A log title is taken from the issue title when the entry is created.

Start starts the issue's timer; Stop pauses it and saves the log in the queue. The card shows active timer duration and the issue's last activity time. The pause-all button in the queue header pauses every running timer.

The build date does not filter the queue by creation date. For example, a Friday entry is available for Monday. A draft-linked log shows its draft date and an action to open it; selecting it again for another day is unavailable. Free stopped source logs can be edited, split, merged with another log, or deleted through the additional-actions menu. History stays within Work; no separate analytics screen is needed.

## Add time dialog

Primary path: **issue → Add time → 3 hours → Save**. Description is optional; no timer start is required.

- When opened from a row, the issue is already selected. When opened with the global button, it shows the active Jira scope's quick issues first, then recent issues without duplicates; if nonempty, the first item is selected by default.
- Fields: issue, hours, minutes, and What was done; hours and minutes default to 1 and 00. A fixed start time can be entered or cleared. Cancel and Save entry appear at the bottom.
- The entry title matches the issue title. No separate required title field is needed.
- The total must be positive; errors appear beside duration without clearing entered data.
- Saving closes the dialog and adds the new stopped entry to the queue. A short message confirms the issue and duration.
- Manual entry neither stops nor replaces an already running timer for that issue.

Editing a free stopped log uses a form for duration, description, and fixed start time. Editing an interval of a built day happens in the day editor.

## Day screen

Before building, an empty state leading to log selection appears only when the date has neither a local draft nor Jira records. Jira loading is shown explicitly; a read error and a successfully loaded empty day are distinct. When Jira records exist, the schedule shows them read-only even without a local draft. For a past date without a draft, the schedule occupies the full width and the log-selection column is hidden. Selecting a date with a saved draft opens that draft. Switching tabs does not lose edits.

| Area | Content and actions |
|---|---|
| Top | Selectable date and menu for previous/next day, today, refreshing Jira records, and rebuilding when a draft exists. Below is a contextual status: suggestion to build a schedule, existing Jira records, saved draft, or submission result. Results can be opened in a separate window when available. An unsubmitted draft has Clear beside Smart Rebuild: confirmation deletes the draft and returns its source logs to the queue. Both commands are unavailable once submission starts. |
| Summary and timeline | For a draft, show day boundaries, full duration including breaks, new/submitted time, existing Jira time, and total breaks. The timeline proportionally shows new intervals, breaks, and imported worklogs; overlapping records occupy separate lanes so all remain visible. Draft intervals have an edit form and draggable start/end handles; Jira intervals are read-only. |
| Sources | With a draft, list selected logs with source and allocated durations, for example “3:00 → 4:07.” Fixing duration prevents resizing the source during rebuild. Without a draft, free stopped logs have checkboxes for current and future dates when Jira records exist; logs held by another draft cannot be selected. For past dates without drafts, hide the column. |
| Schedule | Vertical list of work intervals, breaks, and imported Jira records. An interval shows start, end, duration, issue key/title, description, and, for a draft, submission status. A drag marker reorders work intervals. A generated work interval lasts at least 15 minutes; a break appears between adjacent work intervals. Jira records cannot be edited or resubmitted. |
| Already in Jira | Separately identified occupied intervals; they cannot be edited or resubmitted. |
| Actions | The schedule opens manual interval or break editing; interval menus offer reordering, time locking, splitting, merging parts of the same source, and deletion. The merge dialog does not offer intervals from other sources. The footer shows validity, record count, and the primary submission button. Before submission it says Submit to Jira; after confirmed failures, Retry submission; for an unknown result, Check in Jira. |

The interval edit form changes start, duration, and description; end is computed. The timeline changes start or end by dragging interval edges; the list changes work-interval order by dragging. The menu also offers splitting, merging parts of the same source, time locking, and deletion. Splitting an interval changes only the day schedule and does not create a new queue log. Break actions offer collapsing the break, extending an adjacent task, or setting duration. Below 930 px, schedule and sources stack vertically with scrolling; above that width, sources occupy a 302 px right column. The date is selected in the header; day boundaries are not edited directly on the screen. Section 7 of the specification defines all edits and constraints.

Edits recalculate totals. Work records may overlap; exceeding calendar-day boundaries or overlapping a break with work shows a schedule error and disables submission until corrected. The user sees full day duration with breaks separately from the worklog total: parallel work can make the total exceed the time window's length. For example, a 7:48 day with 0:51 breaks contains 6:57 sequential work; with an existing Jira hour, 5:57 is new.

Before rebuilding a manually edited draft, explain that manual changes will be replaced and allow cancellation. After submission starts, specification restrictions apply; do not allow rebuilding a partially submitted day.

A date with imported Jira worklogs but no local draft shows a read-only Jira schedule. The source sidebar for a new plan appears only for current and future dates. Summary, timeline, submission statuses, and submission footer belong to the local draft. If neither exists, the screen suggests building a day. After draft submission, schedule, timeline, sources, and Jira intervals remain visible. Submission results opens detailed results:

- Success: submitted record count and new time; consumed sources are available in History.
- Partial success: each part shows its result; only permitted unsubmitted parts are retried.
- Uncertain result: an understandable message that the application is checking whether the record appeared in Jira, plus a checking action. Normal resubmission is blocked until reconciliation.

Show why actions are unavailable. Technical states `pending`, `sent`, `failed`, and `unknown` use understandable localized labels; section 10 of the specification defines recovery logic.

## Settings page

Settings opens from the top bar in place of the tabs, without modal dimming. Its fixed header contains a title, Language selector, and System / Light / Dark theme choices; selectors sit beside each other and wrap when width is insufficient. Both controls have the same height and font size as Settings buttons; the language field has a border and theme labels remain on one line. Language choices are system, Russian, and English, with language names displayed in their native spelling. [MVP section 8.2](../specs/jira-time-tracker-mvp.md#82-interface-language) defines language, persistence, and upgrade rules; the language choice is absent from the current Pencil mockup and was added under the agreed specification. Below, left-side navigation contains Jira connection / Day building / Quick issues / Local API; the right side shows only the active section with its own vertical scrolling. There is no General section or Save all button. When width is insufficient, a full-width selector above the content replaces left-side navigation.

The Jira connection saves within its section and successful saving does not close Settings. Day parameters have their own save actions. Local API remains read-only. Quick issues shows the current Jira host/account, an insertion-ordered list, and Add issue. A row contains key, Jira summary, optional hint, hint editing, and shortcut removal; there are no drag handles, categories, enabled checkboxes, or sorting. Without a connection, it leads to the Jira form; an empty catalog shows a compact explanation and add button. Mutating actions are disabled in read-only mode.

In Day building, a multiline Agent build rule field follows the range table. Its hint explains that the agent receives this text along with ranges, while the built-in builder uses only ranges. Reset and Save parameters apply to both form values.

The quick-issue dialog accepts a key, ID, or URL, shows loading and errors beside the field, and after successful verification shows a read-only Jira card and optional Hint field. The local “Configurable quick issues and new settings structure” specification defines Pencil geometry and states in detail. Section 6 of the main specification defines DaySettings values and their effect on drafts.

## Simplifications in the mockup

The mockup shows action placement and navigation using sample data. It can add a manual log, control timers, select logs, build a sample day, edit an interval, and simulate submission. This does not verify MVP implementation.

| Mockup simplification | What the agent must implement |
|---|---|
| In-memory data only; date and existing Jira worklog are examples | Persistence, timer/draft recovery, real dates, and Jira reading according to the specification. |
| Simplified issue addition, search, and filters | Actual key/ID/URL resolution, title loading, search, and activity-age filtering. |
| Demo “New log” is combined with starting | Separate entry creation followed by play according to section 4.2. |
| The builder illustrates allocation; settings range fields do not fully control it | Full section 6 algorithm and constraints, arithmetic and overlap checks. |
| The editor illustrates core actions for one day | All section 7 edits, multiple saved dates, and restrictions after submission. |
| Connection and submission are simulated; uncertain-result checking is simplified | Real credentials, HTTP, submission journal, and duplicate-free reconciliation under sections 8 and 10. |
| Simplified history and availability of some actions | Full lifecycle of free, draft-linked, and consumed logs. |

Do not enter real secrets in the mockup. When moving to Flutter, verify focus order, focus restoration after closing dialogs, and keyboard accessibility.

## Interface verification during implementation

Labels in this document describe the English interface; the Russian interface uses the same actions and states. In narrow windows the application title may ellipsize, issue search and its actions wrap, and the Work footer stacks summary and actions vertically. In short windows the entire built-day screen scrolls so validation messages and submission results do not cover the schedule. Work and Settings also scroll as a whole in small windows; long button labels and messages wrap.

Verify through the UI: three manual hours without description; simultaneous timers for different issues; selecting two logs of the same issue; building for another date; comparing source and allocated time; editing a part; preserving a draft after restart; and recovery after partial or uncertain submission. Corresponding domain checks and completion conditions are already listed in specification scenarios A01–A24.
