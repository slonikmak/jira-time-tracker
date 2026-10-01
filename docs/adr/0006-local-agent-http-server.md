# ADR-0006: Embedded local HTTP server for AI agents

## Status

Accepted

## Context

AI-assisted development (Claude Code, Antigravity, local LLM agents, and shell scripts) needs a way to log work during tasks and prepare workdays without manually clicking through the GUI.

User requirements:

1. Log time against a Jira issue number, with a duration and optional description.
2. List free, unsubmitted logs.
3. Read the current day and existing Jira entries.
4. Upload a complete day built by the agent without using the built-in day-building algorithm.
5. Provide guidance for all actions as text and OpenAPI 3.0.
6. Provide a Settings section with the host/port and a button to copy ready-to-use agent instructions or a skill.
7. Keep final Jira submission under human control through the UI (human-in-the-loop).

## Decision

1. **Lightweight `dart:io` server:**
   - Use standard `HttpServer.bind` without heavyweight dependencies.
   - Listen only on `InternetAddress.loopbackIPv4` (`127.0.0.1`) to exclude requests from other machines.
   - Default to port `8765`, automatically trying the next available port on conflict.
2. **REST API contract:**
   - `GET /api/help`: readable guidance with curl examples.
   - `GET /api/openapi.json`: a valid OpenAPI 3.0 specification.
   - `GET /api/issues?q=...`: search known local issues by key and summary.
   - `GET /api/issues/{issueKey}`: current Jira text, all visible comments, and attachment metadata; `/attachments/{attachmentId}` downloads an attachment belonging to that issue.
   - `GET /api/issues/{issueKey}/worklogs`: all accessible worklogs for the issue, including whether each belongs to the current account.
   - `GET /api/quick-issues`, `POST /api/quick-issues`, `PATCH` and `DELETE /api/quick-issues/{issueId}`: read and manage quick references in the active Jira scope; store local descriptions in `note`.
   - `GET /api/logs`, `POST /api/logs`, `PATCH /api/logs/{id}`, `DELETE /api/logs/{id}`, `/split`, and `/merge`: find and manage source facts. Split a source to place its parts independently, including on different dates.
   - `GET /api/day?date=...`: fresh Jira worklogs, the selected date's draft, and its deterministic revision.
   - `POST /api/day`: atomically replace the agent-built complete draft, validating `base_revision`; work intervals may overlap.
3. **Load issues on demand:**
   - If a logged issue is not cached, fetch metadata through `JiraClient` and cache it. A Jira failure must not produce a synthetic local issue.
   - Remove the obsolete static `/api/service-tickets` and company-specific EG values. Quick issues are not an issue allowlist.
4. **Human-in-the-loop:**
   - The agent builds and passes a draft to the application. The user reviews its timeline on the Day tab and confirms Jira submission.
5. **Ready-to-use agent skill in the UI:**
   - `SettingsDialog` lets users copy a generated system prompt or skill with the current URL and instructions for any AI agent.
6. **Source facts versus day representation:**
   - A LocalLog is a work fact that the agent can freely manage while it is stopped, unused, and not bound to a draft.
   - Every Segment references an existing LocalLog. One source can produce several Segments in one DayDraft and one DraftLog binding; each Segment becomes a separate Jira worklog.
   - To submit parts on different dates, split the LocalLog first. For a single day, interval-editing commands are unnecessary: submit a complete snapshot.
   - A snapshot cannot replace a partially submitted draft; a stale revision cannot overwrite manual edits.

## Consequences

- The application becomes a time-tracking hub for external agents and tools.
- Strict schedule validation (`DayBuilder.validate`) and account safety remain in place.
- Agents must first read a date and pass its revision, preserving concurrent manual edits.
- There is no incremental Segment-editing API: a complete snapshot reduces the command surface and retains one transactional boundary.
