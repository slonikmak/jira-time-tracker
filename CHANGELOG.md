# Changelog

User-visible changes are recorded here in English, newest first. Versioning and
release preparation follow the [release guide](docs/releases.md).

## [Unreleased]

## [0.1.0] - 2026-10-02

### Added

- Parallel issue timers, manual time entry, and a persistent local queue of time logs.
- Jira issue search, a local issue cache, and account-specific quick issues.
- Day planning with configurable breaks, proportional time allocation, and a visual schedule editor.
- Jira Cloud worklog submission with partial-success recovery and reconciliation of uncertain results.
- A local agent API for issue lookup, time-log queue management, and day drafts; worklogs are submitted to Jira through the application UI.
- English and Russian interface selection, saved preferences, and light, dark, and system themes.
- Credential storage in Windows Credential Manager or macOS Keychain and read-only protection for additional application instances.
- Portable Windows x64 packages including the Visual C++ runtime, and experimental macOS packages for Apple Silicon and Intel.

### Known limitations

- macOS packages are ad-hoc signed and are not notarized. Manual testing on a real Mac is required before publication.
