# Specification: Configurable quick issues and new Settings structure

Status: implemented

## Problem Statement

The application contains a built-in catalog of 18 service Jira issues from one company. It cannot be edited, is shared by all Jira connections, and appears in the UI and Local Agent API as a universal product rule. Other teams see foreign keys/descriptions; when Jira is unavailable, the application may materialize such an entry as a synthetic local issue.

Settings simultaneously displays theme, Jira connection, six day-building parameter groups, and Local Agent API. Wide-screen layout assumes exactly three columns; narrower layout becomes one long scrolling page. A complete catalog editor does not fit this structure.

## Solution

Replace built-in service tickets with a user catalog of **quick issues**. A quick issue is a saved reference to an existing Jira issue for repeated selection, not a separate Jira issue type. The catalog belongs to a specific Jira site/account pair, starts empty, and contains only issues explicitly added by the user after successful Jira verification.

Restructure Settings as a separate page with a fixed header, theme choice, and left navigation. Sections are Jira connection, Day building, Quick issues, and Local API. Only the active section appears on the right with its own scrolling and local actions; there is no global save button.

Remove the current EG catalog from the product without automatic migration. Preserve an exact copy only as a local Git-ignored archive, never as initial application data.

## User Stories

1. As a user from any team, I want no built-in tickets from another company so the application fits my Jira.
2. As a connected Jira user, I want to add a frequent issue by key/URL so I can quickly select it again.
3. As a user, I want to see Jira's canonical key/title before saving so I avoid adding the wrong issue.
4. As a user, I want an optional local hint on a quick issue so I remember when to use it.
5. As a user, I want the quick issue title to remain Jira's title so local configuration does not replace the source of truth.
6. As a user, I want an understandable error for inaccessible/nonexistent Jira issues so no fictitious entry is created.
7. As a user, I want insertion order so the catalog stays stable without extra settings.
8. As a user, I want to edit the local hint without changing Jira so I can clarify the shortcut's purpose.
9. As a user, I want to remove a catalog entry without deleting it from Jira, recent issues, logs, drafts, or history.
10. As a user of several Jira sites/accounts, I want a separate catalog for each connection so organizations' issues do not mix.
11. As a user returning to a previous connection, I want its catalog restored without reconfiguration.
12. As a user without a valid connection, I want an explanation and link to connection settings so I understand catalog unavailability.
13. As a new user with an empty catalog, I want to find Quick issues on Work so I learn how to configure it.
14. As a configured user, I want to select a quick issue from a compact menu and immediately enter manual time.
15. As a user of the global Add time dialog, I want quick issues in a separate group without duplicates for faster selection.
16. As a user, I want key/title/optional hint in the menu so I distinguish similar uses.
17. As a Settings user, I want independent sections in left navigation so I avoid scrolling one long page.
18. As a user, I want theme selection always visible in the header rather than buried in a section.
19. As a user, I want theme applied immediately, day parameters saved with their own button, and catalog operations applied individually so outcomes are clear.
20. As a user saving a Jira connection, I want to remain in Settings so I can open Quick issues next.
21. As a narrow-window user, I want section selection above content so left navigation does not consume working width.
22. As a second-instance read-only user, I want to view catalog/settings without changing them so the lock is clear.
23. As a local AI agent, I want quick issues for the active connection so I select recurring issues approved by the user.
24. As a local AI agent, I want key/title/hint/stable order so I explain my choice correctly.
25. As an Agent API user, I want the removed service-ticket name absent from help/OpenAPI so the contract has no company-specific terminology.
26. As a user, I want agents to log against ordinary verified Jira issues outside the catalog so quick issues are a convenience rather than an allowlist.

## Implementation Decisions

- The canonical domain term is `QuickIssue`; user labels are Quick issue / Quick issues. Remove `ServiceTicket` and the built-in corporate-catalog concept.
- `QuickIssue` stores a verified Jira issue reference in the current scope, optional local hint, and addition timestamp. Canonical identity uses Jira issue ID; key/summary come from the linked cached Issue.
- At most one QuickIssue exists per scope/issue pair. Re-adding reports that it already exists without changing position.
- Order by addition time ascending, earliest first. No custom sorting, drag-and-drop, or sort selector.
- New and upgraded installations have empty catalogs. Old EG entries are not automatically imported.
- Addition starts from key, numeric ID, or Jira URL. Resolve through a valid connection before saving QuickIssue. Network/authentication/missing-issue errors create no synthetic local issue.
- Addition dialog states: reference input, loading, found Jira issue, error. Successful lookup shows read-only key/summary, Hint field, and Add action.
- Editing changes only the hint. To replace the Jira issue, remove the shortcut and add another.
- Removal applies immediately and deletes only QuickIssue. Linked Issue, LocalLog, DayDraft, Segment, worklog journal, and history remain unchanged. No extra confirmation or temporary disabling.
- The catalog belongs to Jira base URL + account ID scope. Changing connection immediately changes the catalog; returning restores its entries.
- Without an active verified connection, catalog editing is unavailable; show an explanation and Jira connection action.
- Quick issues always appears on Work. An empty menu explains and offers Configure quick issues. A populated menu follows insertion order; selection opens manual entry with Issue preselected.
- In the global manual-entry dialog, quick issues are a separate first group. An Issue in that group is not repeated among recent issues.
- Rows show key, Jira summary, and optional hint. The hint is a local instruction and is not automatically written to Jira summary or a worklog.
- Settings remains a separate page inside the main shell. Fixed header: title/description left, existing theme choice right.
- Below is a two-column area: four-section navigation left, active content right. Navigation/header do not scroll; only active content does.
- Sections: Jira connection, Day building, Quick issues, Local API. No General section.
- Saving Jira no longer closes Settings: show the result within its section, then allow navigation to Quick issues.
- No Save all or global cancellation. Theme saves immediately; Jira after verification and explicit save; DaySettings with its existing local button; QuickIssue CRUD individually; Local API remains read-only.
- Read-only mode permits navigation, viewing, and Local API copying; theme/connection/DaySettings/QuickIssue changes are disabled with explanation.
- At insufficient width, left navigation becomes a full-width section selector above content. All four sections remain accessible without horizontal scrolling.
- Local Agent API replaces `GET /api/service-tickets` with `GET /api/quick-issues`. Remove the old route, EG references, and service-ticket term from help, OpenAPI, and generated instruction.
- `GET /api/quick-issues` requires active Jira scope and returns insertion-ordered entries with Jira issue ID, key, summary, and optional note. Without a connection return an explicit conflict error, never a global or foreign catalog.
- Agent API does not gain catalog CRUD. Quick-issue configuration remains a user UI action. The catalog does not restrict ordinary Jira lookup or LocalLog creation for verified issues.
- Preserve the corporate list only in a local Git-ignored archive for manual reference, never as a migration source or runtime resource.

## Testing Decisions

- Test observable behavior/domain guarantees rather than table names, SQL queries, private methods, or internal widget composition.
- Main seam: AppState with LocalStore on temporary SQLite and fake JiraClient. Verify successful-lookup addition, failure without synthetic Issue, scope uniqueness, insertion order, hint editing, scope switching, and nondestructive removal.
- Separately prove that two Jira scopes sharing a key do not share QuickIssue and returning restores the previous catalog.
- One end-to-end widget scenario: open Settings, select Quick issues, see empty state, add a verified issue, return to Work, select it, and open manual entry with it preselected.
- Also verify no duplicate in global issue selection, display order, and unavailable CRUD in read-only mode.
- AgentApiServer HTTP seam checks public contract only: active scope, `GET /api/quick-issues` order/fields, no-connection error, removed old route, and consistent help/OpenAPI/generated instruction.
- Existing Jira connection, DaySettings, theme, and SettingsDialog tests protect page restructuring.
- Acceptance includes full `flutter test`, `flutter analyze`, formatting changed Dart files, and `git diff --check`. Create no real Jira worklogs.

## Out of Scope

- Preinstalled/automatically imported corporate catalog.
- Shared catalog across Jira scopes, computers, or users.
- Cloud synchronization, export, or import.
- Groups, tags, categories, pinning, custom sorting, drag-and-drop.
- Enabled flag, archive, or temporary QuickIssue disabling.
- Bulk addition and catalog-page search.
- User renaming of Jira issues; summary always comes from Jira.
- Creating/editing/deleting Jira issues from the application.
- Removing linked issues, logs, days, or history with QuickIssue.
- Agent API QuickIssue CRUD.
- Backward compatibility for `/api/service-tickets`.
- Changes to existing worklog submission/day-building rules.
- Mobile layout or a separate phone design.

## Further Notes

### Pencil Design Brief

Retain the existing `astra.pen` shell, palettes, typography, visual rhythm, and scale. Derive exact dimensions/spacing from the current mockup. Required states follow.

#### 1. Settings — quick issues, populated catalog

- Application top navigation remains unchanged.
- Fixed header: Settings and short description left; existing System / Light / Dark selector right.
- Left navigation has four icon/label rows. Active Quick issues uses the existing selection accent. No General.
- Visually separate navigation from active content.
- Right content is left-aligned; avoid stretching catalog rows uncontrollably across large windows.
- Section heading: Quick issues, explanation “Frequently used issues for the current Jira connection,” primary Add issue button right.
- Below the heading, a quiet context row shows Jira host/account, e.g. `company.atlassian.net · user@example.com`.
- Catalog row: monospaced/accented key beside Jira summary; optional hint on a second line; edit icon and Remove menu right.
- Insertion order. No drag handle, sorting headers, enabled checkbox, or categories.

#### 2. Settings — empty catalog

- Same section geometry.
- Compact empty state rather than a large illustration: icon, “No quick issues yet,” one sentence, and Add issue button.
- Text explicitly associates the catalog with the displayed Jira account.

#### 3. Settings — Jira disconnected

- Retain the section heading.
- Content says to connect Jira first and offers Open connection settings.
- No add action/list; do not show fictitious `default` scope.

#### 4. Add quick issue dialog

- Compact desktop dialog consistent with existing widths/spacing.
- Initial view: Jira issue key or URL field, secondary Cancel, primary Find.
- After lookup, show read-only key/summary card below the field, optional multiline Hint, and primary Add.
- Loading/errors do not abruptly resize the dialog; errors sit beside the field.
- Editing uses the same Jira card but the reference is read-only and only the hint is editable.

#### 5. Work — quick issues menu

- Rename the existing service-ticket action to Quick issues and remove EG-specific tooltip.
- A populated menu shows key, summary, note; selection immediately opens manual time entry with the issue selected.
- An empty menu shows short text and Configure quick issues, leading directly to that Settings section.

#### 6. Narrow window

- At insufficient width, replace left navigation with the current-section selector above content.
- Header may wrap theme below the title, but theme remains visible without opening another section.
- Active content has one vertical scroll area; no horizontal scrolling.

### Acceptance Summary

Design and implementation are correct when the product contains no built-in EG issues or ServiceTicket term, each Jira scope has an independent initially empty QuickIssue catalog, Settings avoids a long combined page, and UI/Agent API use one persisted catalog without synthetic Jira issues.
