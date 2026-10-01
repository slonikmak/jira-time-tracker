# 01: Flutter Desktop foundation, SQLite, single-instance lock, and navigation

**What to build:** A basic Flutter Desktop project for Windows, SQLite-backed LocalStore with schema migrations, a Windows interprocess lock preventing multiple writable instances, and a Material 3 shell with Work/Day tabs and Settings access.

**Blocked by:** None (can start immediately)

**Status:** resolved

## Acceptance criteria

- [x] Initialize the Flutter Desktop (Windows) project at the repository root while preserving existing support files (`AGENTS.md`, `ARCHITECTURE.md`, `.agents/`, `docs/`).
- [x] `LocalStore` initializes SQLite in the application directory with versioning, schema migrations, and `foreign_keys` enabled.
- [x] Implement a Windows interprocess lock (file lock / named mutex): a second process cannot write to the database or submit worklogs (A19).
- [x] The application opens on Windows with basic Material 3 navigation (Work, Day, Settings).
- [x] Unit/integration tests for `LocalStore` use temporary/in-memory SQLite to verify table creation and migrations.

## Answer

Implemented:
- Initialized the Flutter Windows project in the current directory, preserving existing support files.
- Created basic data models (`models.dart`).
- Implemented `LocalStore` (`local_store.dart`), initializing SQLite schema v1, transactional migrations, `PRAGMA foreign_keys = ON`, read-only write protection, and recovery of unfinished `sending` states as `unknown` (A19).
- Implemented `SingleInstanceLock` (`single_instance_lock.dart`) using an exclusive Windows file lock.
- Created the Material 3 shell (`shell_screen.dart`, `app_state.dart`, `main.dart`) with Work/Day tabs, Settings button, and warning banner for a second read-only instance.
- Nine tests pass (`test/local_store_test.dart`, `test/widget_test.dart`).
- Verified Windows compilation (`flutter build windows --debug`).

## Comments
