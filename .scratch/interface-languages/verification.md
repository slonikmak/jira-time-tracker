# Language switching verification

Date: 2026-10-01. Product rules: [MVP section 8.2](../../docs/specs/jira-time-tracker-mvp.md#82-interface-language); original decision: [spec.md](spec.md).

Russian and English interfaces and System default / Russian / English selection beside the theme are implemented. Changes apply immediately and persist. Existing installations retain Russian; new ones use Windows language with English fallback. User text and Jira data remain unchanged.

## Checks performed

- `flutter analyze`: no errors.
- `flutter test`: 239 tests passed, including 22 language checks. Coverage includes new and existing empty installations, SQLite reopening, manual/system selection, save failure and read-only mode, open forms and time dialog, dates, durations and plurals, timer state, selected logs and draft, and old/new saved errors.
- Widget checks for screens and all four Settings sections: both languages/themes, sizes 1152×800, 640×720, and 390×460; application fonts loaded.
- Native Windows debug launch using a separate in-memory SQLite database, in-memory credential storage, and fake HTTP client: cold English startup, Work, Day, Settings, both languages/themes, 1280×850 and 680×800 windows with current Windows scaling. Screenshots were saved and inspected; discovered overflows were fixed. The production database and Jira were not used.
- `git diff --check`: no whitespace errors.

Commands, logs, the disposable native harness, and screenshots are stored in ignored `.local/`; screenshots are in `.local/interface-preview/`.

## Independent review

**Standards:** two findings: storing translated Settings errors and deriving an interval type from diagnostic text. Both were fixed; rechecking the corresponding areas found no issues.

**Spec:** fixed four missing submission/reconciliation message translations, errors in open forms and standard dialogs, and numeric dates in labels/errors. Language coverage received the available scenario ID A29. New errors are stored structurally; old text remains unchanged.

## Release

`flutter build windows --release` succeeded after the final fixes. Complete bundle: `build/windows/x64/runner/Release/`, executable `jira_time_tracker.exe`; distribution also requires the DLLs and `data` directory from that folder.

Checks apply to the current working tree, including appearance changes that predated this task. When committing localization, those changes are separated and retained in the working tree.
