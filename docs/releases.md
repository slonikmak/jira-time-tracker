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

A version tag must match `version` in `pubspec.yaml` without the number after `+`. For example, `version: 0.1.0+1` corresponds to `v0.1.0`. The [release notes helper](../tool/release_notes.py) validates the tag, the build number, and the dated changelog section before a tag build. The tag workflow creates a **draft** GitHub Release only after all three builds succeed. It copies that version's changelog section into the release description and marks `0.x` releases as pre-releases. Reruns update notes and attachments only on drafts; published releases are left unchanged.

## Versioning

The first planned release is `0.1.0`, a preview. During `0.x` development, increase the patch for compatible fixes and the minor version for features or breaking changes; explain compatibility changes in the changelog. Use `1.0.0` once the product and its supported contracts are ready for stable use. From `1.0.0`, follow [Semantic Versioning](https://semver.org/spec/v2.0.0.html): patch for compatible fixes, minor for compatible features, major for breaking changes.

The positive build number after `+` identifies a prepared build. Increment it for subsequent release preparations, including corrections to an unpublished draft. All `0.x` releases remain pre-releases and must not become the stable latest release. The workflow accepts tags in `vMAJOR.MINOR.PATCH` form. Choose a new version and tag if the source changes after tagging; keep every published tag, asset, and changelog section unchanged.

## Changelog

[`CHANGELOG.md`](../CHANGELOG.md) is the source of release notes. Keep a single `## [Unreleased]` section first, followed by versions newest first. Add user-visible entries in the same change as the implementation. Describe the resulting behavior in concise English, rather than copying commit messages or listing internal files. Do not include credentials, personal Jira data, or claims about unfinished work.

Group entries under `### Added`, `### Changed`, `### Fixed`, `### Removed`, or `### Security`; omit empty groups. Use `### Known limitations` for installation or compatibility restrictions that recipients need to know. Internal refactoring, tests, and documentation-only maintenance need no entry unless they change installation or usage.

When preparing a release, move only entries included in the selected commit from `Unreleased` into a dated section such as `## [0.1.0] - 2026-10-02`. The date is the preparation date in the user's local timezone; the section describes a candidate until its GitHub Release is published. Keep an empty `Unreleased` section ready for the next change. Include applicable limitations in each candidate's notes, especially the current macOS signing status. Preserve published sections and put later corrections under `Unreleased`.

Validate and preview notes from the repository root:

```sh
python -m unittest discover -s tool -p "test_release_notes.py"
python tool/release_notes.py v0.1.0
```

A tag needs one dated, nonempty section matching `pubspec.yaml`; validation fails if the entries still only exist under `Unreleased`. GitHub's generated commit or pull-request notes may help review the scope, but do not replace the curated changelog.

## Agent-assisted release

Local agent preparation requires Git, an authenticated GitHub CLI (`gh`), and Python 3.12. GitHub Actions installs Python for the release helper; recipients only need the packaged application.

Use the [desktop-release skill](../.agents/skills/desktop-release/SKILL.md) when preparing a version, assembling release packages, or publishing a release. Example requests: “Prepare a release locally”, “Build a draft release for the current committed changes”, or “Publish the verified draft v0.1.0”. A preparation-only request leaves local changes reviewable. A build request includes pushing the scoped preparation commit and a new tag; it stops at a draft unless publication is explicitly authorized. Existing authorization in the conversation remains valid.

1. Inspect the working tree and release history. Select the intended changes, version, and build number. Preserve unrelated local work; uncommitted files are not part of a tagged package.
2. Update `pubspec.yaml` and the changelog version section. Run the helper tests, preview the notes, and perform application checks appropriate to the included changes. Commit and push the scoped preparation when a built release was requested.
3. Create an annotated tag on the exact preparation commit and push that tag. For example, from that commit:

   ```sh
   git tag -a v0.1.0 -m "Release 0.1.0"
   git push origin v0.1.0
   ```

4. Wait for the tag workflow's three builds and draft release job to succeed. Verify the run's source commit, the notes, the pre-release status, and all three ZIP assets. Download the draft packages with `gh release download v0.1.0 --dir RELEASE_DIRECTORY`. Draft releases are accessible to authorized collaborators, not public visitors. Branch build artifacts still expire after 14 days; published release assets provide the public download location.
5. Test the downloaded packages on Windows and real Macs for the supported architectures. Check startup, saved Jira connections after restart, a timer, a second instance in read-only mode, and the local API. Check macOS installation and Keychain persistence. Submission testing uses a test Jira instance and explicit confirmation in the application UI. Record which checks were performed on which OS and architecture; CI startup alone does not satisfy these manual checks.
6. Once the checks pass and publication is authorized, publish the existing draft with `gh release edit v0.1.0 --draft=false`. Keep its pre-release status. Verify the public release page and its three assets. If manual checks are unavailable or fail, keep the draft and report what remains.

Failed jobs can be rerun after diagnosing the cause. A rerun of the same tag uses the same source; fixes to source require a new version and tag. Never overwrite a published release to repair a package.

## macOS signing

Current Mac packages use the standard Flutter project's ad-hoc signature and **are not notarized**. These are preview builds; macOS may block a downloaded application. Convenient public installation requires a Developer ID Application certificate and Apple notarization. These are not configured in the workflow yet. Until they are, label Mac packages experimental and require testing on a Mac before publication.

Provide the signing certificate, its password, and notarization credentials through GitHub Actions secrets. Keep them out of sources, the repository, and releases. A signing workflow will be a separate change after the owner supplies these credentials. MSIX/DMG installers and automatic updates are unnecessary for the first release: archives and GitHub Releases provide versioned distribution.

Sources: [GitHub runners](https://docs.github.com/en/actions/reference/runners/github-hosted-runners), [Flutter Windows ZIP and runtime](https://docs.flutter.dev/platform-integration/windows/building#building-your-own-zip-file-for-windows), [Flutter macOS entitlements and signing](https://docs.flutter.dev/platform-integration/macos/building), [macOS Keychain](https://pub.dev/packages/flutter_secure_storage).
