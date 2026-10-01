# Builds and distribution

The application is **Jira Time Tracker**; the repository is `jira-time-tracker`.
The initial distribution method is GitHub Releases with application archives:

| Package | Contents | Installation |
|---|---|---|
| `jira-time-tracker-windows-x64.zip` | exe, DLLs, Visual C++ runtime, and `data` | Extract the entire folder and run `jira_time_tracker.exe` |
| `jira-time-tracker-macos-arm64.zip` | `Jira Time Tracker.app` for Apple Silicon | Extract and move the application to Applications |
| `jira-time-tracker-macos-x64.zip` | `Jira Time Tracker.app` for Intel | Extract and move the application to Applications |

Updating replaces the application and its libraries. Keep the user's SQLite database and system credential storage. Data paths and connection rules are documented in the [README](../README.md).

The [packaging script](../tool/package_windows.ps1) creates the Windows archive. It includes `msvcp140.dll`, `vcruntime140.dll`, and `vcruntime140_1.dll` next to the exe, so recipients do not need to install Visual C++ Redistributable separately.

## GitHub Actions

The [workflow](../.github/workflows/desktop-release.yml) runs on pushes to `main`, pull requests, `v*` tags, and manual dispatch. It uses Flutter **3.41.3**, locked dependencies from `pubspec.lock`, the analyzer, tests, and release builds.

After building, it starts the application and checks `GET /api/day-settings` through the local API. This verifies native startup, SQLite, and credential reads on a clean runner without connecting to production Jira. Each platform builds on its own OS: Windows x64, macOS arm64, and macOS x64. Archives are available as run artifacts for 14 days.

A version tag must match `version` in `pubspec.yaml` without the number after `+`. For example, `version: 1.0.0+1` corresponds to `v1.0.0`. Update both numbers before a new version. The tag workflow creates a **draft** GitHub Release only after all three builds succeed. Reruns replace attachments only on drafts; published releases are left unchanged.

1. Commit the prepared sources and push them to GitHub.
2. Wait for all three builds to succeed and download the artifacts for testing.
3. On Windows and a real Mac, test startup, saved connections after restart, a timer, a second instance in read-only mode, and the local API. Test submission using a test Jira instance and explicit confirmation in the UI.
4. After testing, create and push a tag such as `v1.0.0`.
5. Review the draft release's attachments and description, then publish it.

## macOS signing

Current Mac packages use the standard Flutter project's ad-hoc signature and **are not notarized**. These are preview builds; macOS may block a downloaded application. Convenient public installation requires a Developer ID Application certificate and Apple notarization. These are not configured in the workflow yet. Until they are, label Mac packages experimental and require testing on a Mac before publication.

Provide the signing certificate, its password, and notarization credentials through GitHub Actions secrets. Keep them out of sources, the repository, and releases. A signing workflow will be a separate change after the owner supplies these credentials. MSIX/DMG installers and automatic updates are unnecessary for the first release: archives and GitHub Releases provide versioned distribution.

Sources: [GitHub runners](https://docs.github.com/en/actions/reference/runners/github-hosted-runners), [Flutter Windows ZIP and runtime](https://docs.flutter.dev/platform-integration/windows/building#building-your-own-zip-file-for-windows), [Flutter macOS entitlements and signing](https://docs.flutter.dev/platform-integration/macos/building), [macOS Keychain](https://pub.dev/packages/flutter_secure_storage).
