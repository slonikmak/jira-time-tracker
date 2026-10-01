# Interface language switching: Russian and English

Status: implemented

Date: 2026-10-01.

Product decisions, verification, and task breakdown were agreed in the `ask-matt` → `grill-with-docs` interview on 2026-10-01.

## Problem Statement

Jira Time Tracker has a Russian interface. The user wants to use the same application in Russian or English, switch without restarting, and preserve current work. Translating tabs alone is insufficient: forms, messages, calendar, and application errors must follow the selected language.

## Solution

The fixed Settings header gains a Language selector beside the theme. It offers System default / Russian / English; the English system option is named “System default.” Language names always use their native spelling.

The choice applies immediately and persists on this device. In system mode, Russian Windows selects Russian; English and other Windows languages select English. Language region does not change this rule. New installations begin in system mode; on first upgrade, existing installations explicitly retain Russian. The user may then choose any of the three options.

Translate all application-owned interface text, including application errors, hints, empty states, save messages, calendar, duration units, and standard dialogs. Jira issue titles/statuses, worklog text, LocalLog descriptions/titles, QuickIssue local hints, and editable user instructions remain unchanged. Jira Time Tracker, issue keys, addresses, and identifiers are not translated.

Month and weekday names follow the language. Numeric dates retain day–month–year order (`30.09.2026`); time remains 24-hour (`14:05`). Short dates may retain their current length (`30.09`). Changing language does not change time zone, calendar date, durations, or time values.

Jira error text and previously saved errors appear unchanged. This is an agreed limitation; new application-owned messages must support both languages.

## User Stories

1. As a Russian Windows user, I want Russian on a new installation so I can start without configuring language.
2. As an English Windows user, I want English on a new installation so I understand application actions.
3. As a user of Windows in another language, I want English so I obtain a supported language without blank labels.
4. As an existing-installation user, I want to retain Russian after upgrading so language does not change unexpectedly.
5. As a user, I want to select Russian independently of Windows to keep my preferred language.
6. As a user, I want to select English independently of Windows to keep my preferred language.
7. As a user, I want to restore System default so the application follows Windows language again.
8. As a user, I want recognizable native language names so I can find my language in an unfamiliar interface.
9. As a user, I want immediate switching so I need not restart.
10. As a user, I want my choice retained between launches so I need not configure it repeatedly.
11. As a user, I want one language setting for all Jira connections so the interface does not depend on the account.
12. As a user, I want all tabs and Settings sections translated so the entire navigation is understandable.
13. As a user, I want manual-time, editing, splitting, and merging forms translated so I can act in my chosen language.
14. As a user, I want queue, history, and day schedule translated so I understand record states.
15. As a user, I want hints, warnings, and confirmations translated so I understand consequences.
16. As a user, I want application errors in my language so I can correct input and recover from failures.
17. As a user, I want calendar and month names in my language so I can select the right date.
18. As a user, I want day–month–year numeric dates and 24-hour time in both languages so I do not confuse dates or hours.
19. As a user, I want duration units and record counts in my language so I read totals correctly.
20. As a user, I want form input preserved when language changes so I need not enter it again.
21. As a user, I want selected date/logs, draft, and running timers preserved during switching so work is uninterrupted.
22. As a user, I want original Jira issue titles and my descriptions retained so switching does not change recorded content.
23. As a user, I want original Jira and old submission errors retained so diagnostic information survives.
24. As a narrow-window user, I want accessible language/theme selectors without overflow at every supported width.
25. As a dark-theme user, I want the same selector and readable translations so language does not constrain appearance.
26. As a user, I want localized read-only explanations so I understand why Settings changes are unavailable.

## Implementation Decisions

- Language belongs to the application/device, not Jira scope, DaySettings, or a DayDraft snapshot.
- Store the user's choice (`system`, `ru`, or `en`), not merely the resolved language. Manual selection overrides Windows language.
- In system mode, a system-language change updates the interface if the platform reports changes while running; the next launch always uses the new system language.
- A missing setting in an old installation does not imply a new installation. Distinguish a new database from an existing one before initialization/migrations erase that distinction. An existing empty database also receives Russian on upgrade.
- Initialize an existing installation's choice once in the writable instance. Save failure must not silently confirm a change; restarting must not unexpectedly switch an old installation to English.
- Use standard Flutter localization with Russian/English catalogs, parameters, and plural rules. Do not assemble translations from Russian sentence fragments or call a network translation service at runtime.
- Material dialogs, calendar, and time picker share the screens' language; force 24-hour time.
- AppState coordinates language selection; LocalStore owns persistence; UI presents localized text. SQL and Windows language reading do not move into widgets.
- Pure domain modules do not depend on Flutter or BuildContext. Represent application-owned errors so the UI can translate with original parameters; retain technical causes and Jira messages.
- Previously persisted error strings remain compatible and are not rewritten by translation. New application-owned interface messages support both languages, including submission/recovery.
- Numeric dates, times of day, and durations are formatted consistently across screens. Date order and 24-hour format do not depend on the English regional variant.
- Changing language updates labels without recreating user state: preserve navigation, fields, selected logs/date, timers, draft, loading state, and submission results.
- In narrow windows the Settings header wraps without horizontal overflow; retain current scale, typography, themes, and sections.
- Disable language changes in a read-only instance, as for theme changes. Viewing current language and localized explanations remains available.
- Failure to save language leaves the previous persisted choice and shows an understandable message.
- Language switching neither submits worklogs nor changes building rules or the public Local Agent API contract. Editable agent instructions are not translated automatically.
- The completed version leaves no untranslated application-owned Russian labels in English UI. Searching for remaining strings is a supporting check; Jira data and user text may legitimately remain Russian.

## Testing Decisions

- The main verification boundary is the real application in widget tests with AppState, temporary SQLite, fake Jira HTTP client, and in-memory secure storage. This is the existing shell, Settings, and QuickIssue testing approach.
- Verify observable Settings behavior and subsequent presentation rather than private methods, SQLite key names, or exact internal widget composition.
- Supply platform language and clocks explicitly so results do not depend on the developer's Windows machine. Supply builder randomness explicitly when scenarios need DayDraft.
- Separate scenarios: new installations with Russian, English, and unsupported languages; existing database without language setting; restart after manual choice; restoring system selection; save failure; read-only mode.
- Restart verification closes and reopens a temporary file-backed SQLite database; reusing the same live AppState does not prove persistence.
- An end-to-end scenario switches language in Settings and checks shell, Work, Day, forms, messages, and calendar. Changing system language with an open form checks input preservation.
- A current-work scenario preserves selected logs/date, running timer, LocalLog, and DayDraft after switching; no Jira submission requests are created.
- The fake Jira client returns original Russian/English titles and errors: data remains unchanged while the application's own explanation is translated.
- Verify new application-owned errors separately from old persisted error strings, including submission results and restart recovery.
- Verify dates, 24-hour times, month names, duration units, and record counts in both languages, including 1, 2, and 5 records and regional English variants.
- Check both languages in wide/narrow layouts and light/dark themes; long English labels do not overflow forms or header.
- Regression covers affected scenarios A01–A24. Development checks use fake HTTP and create no worklogs in production Jira.
- Final acceptance: Dart formatting, `flutter analyze`, full `flutter test`, `git diff --check`, Windows release build, and main-screen verification in the built application in both languages.

## Out of Scope

- A third language and additional regional date/time formats.
- Automatic translation of Jira data, user descriptions, hints, or instructions.
- Translation of previously persisted error strings or Jira error text.
- Changing the external Local Agent API schema/semantics for UI language.
- Translating all project Markdown documents into English as part of this interface-localization task.
- Redesigning visual style, navigation, building/submission algorithms, or work-data storage.
- Synchronizing language across devices/installations.

## Further Notes

Before implementation, the code had no localization infrastructure. Russian strings occurred in UI, AppState, and domain modules; dates and durations were formatted in several places. Theme already persisted locally and applied immediately. These facts were verified in the repository; implementation and verification results are recorded in related tasks.

Owning documents: [MVP](../../docs/specs/jira-time-tracker-mvp.md), [UX/UI](../../docs/design/UX.md), [architecture](../../ARCHITECTURE.md), [README](../../README.md). Implementation must update the language rule in MVP, selector placement in UX/UI, localization ownership in architecture, and setup steps in README. Other documents should link to the rule's owner. Historical specifications of completed tasks are not rewritten for behavioral changes.

The working tree already contains mockup, UX, shell, screen, and widget-test changes. Preserve them; localization implementation accounts for the current tree. Code and documentation must not declare localization implemented before verified completion.

### Agreed breakdown

1. **Language selection, persistence, and shell.** No blockers. The user selects language in the Settings header; the shell switches immediately. New installation, old-installation upgrade, system selection, restart, and read-only behavior work. Establish translation catalogs without removing existing behavior.
2. **Work, queue, history, and log forms.** Blocked by task 1. Translate the entire path from Issue selection/manual entry to timers, LocalLog selection, splitting, and merging. Verify dates, durations, messages, and states; preserve data.
3. **Day, editor, and submission results.** Blocked by task 1. Translate calendar, schedule, Segment and Timeline Gap actions, building checks, confirmations, errors, and submission recovery. Verify DayDraft preservation and old-error compatibility. All network scenarios use fake Jira.
4. **Remaining Settings and a ready Windows version.** Blocked by tasks 2 and 3. Fully translate Jira connection, DaySettings, QuickIssue, and Local API presentation; verify coverage and preservation of user instructions. Update owning documents, check both layouts/themes, and run full checks and release build.

Individual task files are in `issues/`, in dependency order. Intermediate tasks deliver verifiable interface slices; complete switching of all application-owned text is the result of completing all four.

### Implementation completion

2026-10-01: All four tasks completed; see [verification and release](verification.md).
