# Jira Time Tracker (Windows and macOS)

A local Flutter desktop application for tracking work time, running parallel issue timers, planning a workday, and reliably submitting worklogs to Jira Cloud REST API v3. Windows and macOS builds are tested for startup in GitHub Actions. macOS support is experimental and requires manual testing on a Mac before a release.

The interface supports English and Russian. Project documentation is maintained in English.

Download published packages from [GitHub Releases](https://github.com/slonikmak/jira-time-tracker/releases). Before the first publication, builds are available as artifacts in [GitHub Actions](https://github.com/slonikmak/jira-time-tracker/actions/workflows/desktop-release.yml). See the [changelog](CHANGELOG.md) for changes and the [release guide](docs/releases.md) for package formats and publication. Release preparation can be delegated to the repository's [desktop-release skill](.agents/skills/desktop-release/SKILL.md).

End-to-end workflows for people and local AI agents are covered in the [user stories](docs/specs/user-stories.md). Detailed product rules and acceptance scenarios A01–A24 are defined in the [MVP specification](docs/specs/jira-time-tracker-mvp.md).

## 1. Features

- **Parallel timers and manual time entry:**
  - Run multiple issue timers at the same time.
  - Timers survive hibernation, sleep, and application restarts: elapsed time is calculated from persistent UTC timestamps (`LogClock`).
  - Add time manually, such as a three-hour call without a running timer.
  - Edit descriptions and durations in the queue of unused logs.

- **Issue catalog and search:**
  - Cache issues in a local SQLite database.
  - Find and add issues by key (`PROJ-123`) or a direct issue URL.
  - Configure quick issues separately for each Jira site and account, with Jira validation, a local note, and a shortcut to manual time entry.
  - Filter by recent use: seven days, 30 days, or all time.

- **Day planning (`DayBuilder`):**
  - Generate a deterministic schedule using a stored random `seed`.
  - Account for existing Jira worklogs when finding available time slots.
  - Schedule a long break and short breaks using configurable ranges.
  - Distribute accumulated issue time proportionally, with whole-second precision.
  - Preserve the exact duration of locked issues (`durationLocked`).
  - Split large intervals into smaller parts while retaining their descriptions and source-log references.
  - Automatic builds use saved ranges; manual and agent-created drafts can contain parallel work intervals.

- **Visual schedule editor:**
  - Navigate between dates and see total time, issue totals, and breaks.
  - Adjust interval start times and durations interactively.
  - View parallel work intervals on separate tracks. Intervals outside the selected date and breaks overlapping work block submission.
  - The draft's composition is locked once submission begins.

- **Reliable Jira Cloud submission and recovery:**
  - Submit intervals individually with `adjustEstimate=leave` and comments in Atlassian Document Format (ADF).
  - Attach the `jira-time-tracker.segment` property to each worklog, with the value `{id: <segment UUID>}`.
  - Persist the request body and `sending` status in a SQLite transaction before making the network request.
  - Mark a source log as `consumed` only when **all** its segments are `sent`.
  - Preserve confirmed results after partial success; another submission sends only the remaining eligible intervals.
  - Treat an interrupted connection or timeout as `unknown`; blind retries are blocked.
  - Reconcile results by looking for the segment property in Jira worklogs, avoiding duplicate POST requests.
  - Resolve an unknown result manually by verifying an existing worklog ID or explicitly confirming that the entry does not exist.

- **Multiple-instance protection and credential storage:**
  - An interprocess file lock (`app.lock`) allows only one instance to write. Additional instances open in read-only mode.
  - Credentials and API tokens are stored in Windows Credential Manager or macOS Keychain, outside SQLite, text files, and logs.

## 2. Requirements, installation, and builds

### System requirements

- **Operating system:** Windows 10/11 x64; macOS 10.15+ on Apple Silicon or Intel, with experimental support.
- **For development and builds:**
  - Flutter SDK 3.41.3, stable channel, matching GitHub Actions.
  - Windows: Visual Studio 2022 with the **Desktop development with C++** workload.
  - macOS: a Mac with Xcode and CocoaPods. macOS builds require macOS.
  - Git.

### Clone and install dependencies

```sh
git clone https://github.com/slonikmak/jira-time-tracker.git
cd jira-time-tracker
flutter pub get
```

### Run tests

```sh
flutter test
```

### Run the application

On Windows:

```sh
flutter run -d windows
```

On macOS:

```sh
flutter run -d macos
```

For UI testing through Dart/Flutter MCP, enable Flutter Driver in a debug build:

```sh
flutter run -d windows --dart-define=ENABLE_FLUTTER_DRIVER=true --print-dtd
```

Use `-d macos` when testing on a Mac. To compare the UI with the Pencil design, add `--dart-define=UI_PREVIEW_LIGHT=true` or `--dart-define=UI_PREVIEW_DARK=true`.

Flutter Driver disables physical keyboard input in this mode; enter text through MCP. For normal manual use, run without the driver flag.

### Build a Windows release package

```powershell
flutter build windows --release
./tool/package_windows.ps1
```

The executable and its dependencies are built in `build/windows/x64/runner/Release/`.

The distributable ZIP is `dist/jira-time-tracker-windows-x64.zip`. The packaging script adds the Visual C++ runtime libraries from the installed Visual Studio and archives the entire bundle. Use this ZIP for distribution.

### Build a macOS release

```sh
flutter build macos --release
```

The application bundle is `build/macos/Build/Products/Release/Jira Time Tracker.app`.

Credentials are stored in the system Keychain. The release application has network permissions for Jira and the local API. Current Mac packages are not notarized; see the [release guide](docs/releases.md) for publication requirements.

## 3. Settings and Jira Cloud connection

At the top of **Settings**, choose **Language**: **System default**, Russian, or English. The theme selector is next to it. Both preferences apply immediately and are saved on this computer. First-launch behavior, upgrades, and translation boundaries are defined in [MVP section 8.2](docs/specs/jira-time-tracker-mvp.md#82-interface-language).

Use the sidebar to select **Jira connection**, **Day build**, **Quick issues**, or **Local API**. In a narrow window, a selector above the content replaces the sidebar.

### Option 1: Application settings

Open **Settings** in the upper-right corner and fill in:

- **Jira address:** your Jira site URL, such as `https://your-company.atlassian.net`.
- **Email:** the email address of your Atlassian account.
- **API token:** a Jira Cloud API token, created in [Atlassian Account API Tokens](https://id.atlassian.com/manage-profile/security/api-tokens).

**Check connection** verifies API access through the standard `/rest/api/3/myself` route and the scoped Atlassian Gateway routes (`/_edge/tenant_info` and `/ex/jira/{cloudId}/rest/api/3/myself`). **Save** stores the verified connection in Windows Credential Manager or macOS Keychain.

### Option 2: Environment variables

To populate the form without entering each value manually, set these environment variables for the application process:

- `JIRA_BASE_URL`: the Jira base URL. The current fallback is `https://esprowteam.atlassian.net`; set your own site's URL.
- `JIRA_EMAIL`: your account email address.
- `JIRA_TOKEN`: your API token.

If a connection has already been saved through the UI, its settings take precedence over environment variables. Cancelling edits does not clear an existing connection.

### Quick issues

Add an existing Jira issue by key, numeric ID, or URL. The application first displays the key and title retrieved from Jira and saves the reference only after validation succeeds. An optional note stays local.

The list belongs to the current Jira site and account and is shown in insertion order. Removing a quick-issue reference does not delete the Jira issue, logs, or history.

### Local API

The primary application instance runs an HTTP API on `127.0.0.1`, usually on port `8765`. Copy its actual address and agent instructions from **Local API** in Settings.

- `GET /api/help` returns usage guidance; `GET /api/openapi.json` returns the complete API contract.
- Before building a day, an agent reads `GET /api/day-settings`. One response contains the current numeric ranges and the editable day-build rule.
- `GET /api/issues/PROJ-123` reads the current Jira issue, all accessible comments, and attachment metadata. `GET /api/issues/PROJ-123/attachments/10001` downloads one attachment by ID.
- `GET /api/quick-issues` returns quick issues and local `note` values. `POST /api/quick-issues`, `PATCH /api/quick-issues/{issueId}`, and `DELETE /api/quick-issues/{issueId}` manage this list.
- The API can read the local queue and Jira worklogs by date or issue, create local logs, and save a complete day draft, including parallel work intervals.

Submitting worklogs to Jira requires confirmation in the application UI.

### Day-build settings

In **Day build**, configure ranges for the day's start time and duration, the long break's start time and duration, and the number and duration of short breaks. Enter times as `HH:MM`, durations such as `7 h 30 m` or `45 m`, and break counts as whole numbers. **From** values must not exceed **To** values; validation errors appear beside the affected row.

**Save settings** saves the ranges and the agent's text rule. **Reset** fills the form with defaults; click **Save settings** to persist them. How these settings affect building and rebuilding a day is defined in [MVP section 6.1](docs/specs/jira-time-tracker-mvp.md#61-default-settings).

On the **Day** screen, **Clear** asks for confirmation, deletes the unsubmitted draft, and returns its source logs to the queue.

## 4. Local data and security

On Windows, application data is stored in the standard application support directory (`getApplicationSupportDirectory`):

```text
%APPDATA%\com.example\jira_time_tracker\
```

On macOS, the sandboxed application's support directory is typically:

```text
~/Library/Containers/com.slonikmak.jiraTimeTracker/Data/Library/Application Support/com.slonikmak.jiraTimeTracker/
```

macOS determines the exact path. The application creates these files in its support directory:

- `jira_time_tracker.db`: the SQLite database containing cached issues, scoped quick issues, local logs, day drafts, segments, breaks, appearance preferences, and day-build settings.
- `app.lock`: the interprocess lock for the single writable instance.

### Credentials

API tokens are stored exclusively in **Windows Credential Manager** through Win32 APIs or in **macOS Keychain**. Windows retains the `JiraTimeTracker:` prefix; macOS uses the `JiraTimeTracker` Keychain service. Tokens are excluded from SQLite and logs and are sent only to the selected Jira API for authentication.

## 5. Offline use and timers

1. **Timers and sleep:** elapsed time does not depend on UI timer ticks. Starting a timer records `runningSinceUtc`; after closing the application or putting the computer to sleep, elapsed time is calculated from that timestamp when the application is reopened.
2. **Pause:** pausing stores elapsed time in `accumulatedSeconds` and clears `runningSinceUtc`.
3. **Offline use:** timers, accumulated time, manual entries, and day-draft generation work offline. Network access is required to find new issues, load existing Jira worklogs, and submit time to Jira.

## 6. Limitations and submission recovery

### JQL `worklogDate` limitation

Atlassian's JQL `worklogDate` field searches only the most recent 1,000 worklogs per issue. Older entries may therefore be missing from historical search results.

### Duplicate protection and `unknown` results

- If a submission is interrupted by a network failure, a gateway timeout (504/502), or a server error such as HTTP 500, the segment moves to **Unknown** (`unknown`).
- **Blind retries are blocked:** Jira may have created the entry before the connection failed.
- **Reconcile result:** the application loads the issue's worklogs and looks for the `jira-time-tracker.segment` property with the segment ID. A matching entry is checked for author and duration, then marked **Sent** without another POST request.
- **Manual resolution:**
  1. **Enter the ID of the created Jira entry:** enter the ID of a worklog visible in Jira; the application verifies it and links it to the interval.
  2. **No entry in Jira, allow retry:** after checking Jira and confirming that the entry does not exist, reset the interval to Pending so it can be submitted again.
