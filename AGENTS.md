# Working on Jira Time Tracker

This is a local Flutter application for Windows and macOS. The interface supports Russian and English under the [MVP language rules](docs/specs/jira-time-tracker-mvp.md#82-interface-language). Project documentation and Dart identifiers use English. Builds and publication are described in the [release guide](docs/releases.md).

## Sources by task type

Read the relevant sections before changing behavior:

| Task | Source of rules |
|---|---|
| User value, story map, and agent workflows | [User stories](docs/specs/user-stories.md); exact rules remain in the linked MVP and API contracts |
| User workflows, time rules, acceptance criteria | [MVP specification](docs/specs/jira-time-tracker-mvp.md), including scenarios A01–A24 |
| Persistence errors, Jira requests, incomplete loading, submission, recovery | [MVP specification](docs/specs/jira-time-tracker-mvp.md), sections 10–11 |
| Module boundaries, data, transactions, test dependencies | [ARCHITECTURE.md](ARCHITECTURE.md) |
| Screens, forms, navigation, appearance | [UX/UI](docs/design/UX.md) and the current [astra.pen](astra.pen) design |
| Installation, running, usage | [README.md](README.md) |
| Changelog, versions, builds, release publication | [Release guide](docs/releases.md); use the [desktop-release skill](.agents/skills/desktop-release/SKILL.md) for preparing, building, or publishing a release |
| Domain terms and architectural decisions | [CONTEXT.md](CONTEXT.md) and applicable ADRs under the [domain documentation rules](docs/agents/domain.md) |

User instructions take precedence. If they change an agreed rule, update its owning document. Verify actual behavior against code and execution results: a description of intended behavior does not prove implementation. Describe any discrepancy concretely.

## Making changes

1. Inspect the working tree and affected code. Preserve unrelated changes.
2. Fix the rule in its owning module, then update callers as needed. Keep SQL, the Jira protocol, and day building behind their respective module interfaces.
3. When changing a contract, layout, module responsibility, or startup method, update the owning document from the table above. Link to it from other documents instead of duplicating the rule.
4. For user-visible features, fixes, removals, compatibility changes, or security changes, update `CHANGELOG.md` under `Unreleased` in the same change. Write concise English descriptions of the resulting behavior, following the [changelog rules](docs/releases.md#changelog). Internal refactoring, tests, and documentation-only changes need no entry unless they affect installation or usage. Keep published version sections unchanged; the release skill moves eligible entries into a version section.

For local tasks in `.scratch/`, use the [issue tracker rules](docs/agents/issue-tracker.md). For incoming task triage, use the [label vocabulary](docs/agents/triage-labels.md).

## Matt skills

Use suitable automatically invocable skills from [`.agents/skills/`](.agents/skills/) when the task matches their description. Examples: `diagnosing-bugs` for a difficult bug, `codebase-design` for a module boundary, `code-review` for reviewing changes, and `writing-for-agents` for editing `AGENTS.md` or a skill. Read the chosen `SKILL.md` and its required materials before working.

Use `ask-matt` and skills marked for explicit invocation when the user names them. A routine narrow task does not require the complete Matt flow.

## Verification

- For changed logic, verify the related scenarios in specification section 12. Use `flutter_test`, a fake HTTP client, and temporary SQLite databases; pass clocks and randomness explicitly.
- Development checks do not create worklogs in production Jira. Distinguish test execution from user submission. Keep secrets out of source files, tests, logs, and reports.
- For a narrow change, run checks matching its impact. For full application verification, run the commands and Windows release build from specification section 13.
- Report changes, checks actually performed, remaining limitations, and the build path if a build was produced.
