# 02: Jira connection settings (Env, SecureStore, route verification)

**What to build:** ConnectionStore credential management and JiraClient authentication. Read environment variables (`JIRA_BASE_URL`, `JIRA_EMAIL`, `JIRA_TOKEN`), store credentials securely in Windows (`WindowsCredentialStorage`), verify connections read-only through two routes (direct GET `/rest/api/3/myself` and scoped via `/_edge/tenant_info`), and provide a Settings modal with token masking and cancellation.

**Blocked by:** 01: Flutter Desktop foundation, SQLite, single-instance lock, and navigation

**Status:** resolved

## Acceptance criteria

- [x] `ConnectionStore` reads process environment on first launch; saved user input takes precedence when reopening the form (A16).
- [x] Store the API token only in secure Windows storage (`WindowsCredentialStorage`), never in SQLite, plaintext logs, or README.
- [x] Canceling Settings edits preserves the previous verified connection (A16).
- [x] `JiraClient` verifies read-only: first try direct GET `/rest/api/3/myself`; on refusal, check the scoped route with `cloudId` from `/_edge/tenant_info` (A17).
- [x] Settings masks the token and displays user name/`accountId` on success or an understandable error reason.
- [x] Fake `http.Client` (`MockClient`) tests cover A16/A17, including 401, 403, and network failures.

## Answer

Ticket 02 is fully implemented:
- Created `secure_storage.dart` with `SecureStorage`, `InMemorySecureStorage` for tests, and `WindowsCredentialStorage` (native Windows Credential Manager FFI). Tokens never enter SQLite, logs, or plaintext files.
- Created `connection_store.dart` (`ConnectionStore`): environment reading (`JIRA_BASE_URL`, `JIRA_EMAIL`, `JIRA_TOKEN`), saved-value precedence, and secure storage of metadata/token.
- Created `jira_client.dart` (`JiraClient`): read-only GET `/rest/api/3/myself`, scoped routing with `cloudId` from `/_edge/tenant_info` after direct-route 401, and 401/403/429 handling (with `Retry-After`).
- Created `lib/ui/settings_dialog.dart` with token masking, connection test button, account display, and safe cancellation (A16).
- Extended `AppState` with `activeScope` (`baseUrl#accountId`) and the current verified connection (A17).
- Nine tests pass in `test/jira_connection_test.dart` (18 project tests total).
- Verified Windows build (`flutter build windows --debug`).

## Comments
