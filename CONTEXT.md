# Jira Time Tracker

A local Flutter Desktop application for Windows and macOS that tracks developers' work time, builds day schedules, and reliably submits worklogs to Jira.

## Language

### Logs and issues

**LocalLog**:
An original record of time spent on one issue, created by a timer, manual entry, or the Local Agent API. A LocalLog can be projected into one or more Segments of one DayDraft. To place parts on different dates, first create independent LocalLogs.
_Avoid_: Timer, Time entry, Worklog

**Issue**:
A cached Jira issue record (key, summary, status, last interaction time) against which time is tracked.
_Avoid_: Task, Ticket

**QuickIssue**:
A user-saved reference to an existing Issue for quick repeated selection. Its catalog belongs to a specific Jira site and account and does not determine the issue's type or purpose in Jira.
_Avoid_: ServiceTicket, built-in company catalog, separate Jira issue type

### Building and scheduling

**DayDraft**:
A draft schedule for a specific calendar date within the active Jira connection.
_Avoid_: Plan, Schedule, Day plan

**DraftLog**:
The association of one LocalLog with one DayDraft, including a snapshot of its original duration and description when built. There is exactly one association per draft/source pair, even if the source is represented by several Segments.
_Avoid_: Segment, Copied log, Worklog

**Segment**:
A single working interval in a DayDraft with a reference to exactly one LocalLog. One LocalLog can produce several Segments on the same day; after submission, each Segment corresponds to one Jira worklog. Splitting a Segment changes the day's representation without creating a new LocalLog.
_Avoid_: Chunk, Worklog draft, Interval

**ExistingWorklog**:
A worklog already in Jira, available for reading and considered during day building. It may overlap other work intervals.
_Avoid_: Remote log, Imported worklog

**As-Recorded Build**:
The default day-building mode (**Build day**): transfers logs to the timeline at their original local times, shifting overlaps without splitting issues lasting $\le 1$ hour.
_Avoid_: Simple build, Raw build

**Smart Rebuild**:
Algorithmic schedule optimization (**Smart rebuild**): plans a long break and short breaks and splits issues lasting more than one hour.
_Avoid_: Auto build, Magic build

**DaySettings**:
Application-wide ranges for the day's start and duration, the long break, and additional short breaks, used by the algorithmic rebuild. A saved DayDraft contains a snapshot of the settings used for its latest generation.
_Avoid_: Jira-account settings, settings of the open draft

**Agent Day Rule**:
A user-editable text rule describing how an AI agent should apply DaySettings when preparing a schedule. It does not change the built-in algorithmic builder.
_Avoid_: Builder algorithm, per-account rule

**Timeline Gap**:
A computed interval within day boundaries that is not occupied by any work interval. All breaks have equal status; lunch is no longer a separate entity. A gap is not a static database record.
_Avoid_: Break entity, Empty slot, Hole

**Ripple Push**:
Cascading movement of subsequent work intervals to the right when an issue or gap grows, strictly preserving the original durations of all affected issues.
_Avoid_: Task truncate, Neighbor resize, Force squeeze

**Gap Actions**:
Contextual actions on free time: **Close gap** (move intervals together), **Fill gap** (extend work into the gap), and **Set duration** (ripple-push later intervals).
_Avoid_: Manual break edit dialog, Break interval hack

**Timeline Drag Handles**:
Interactive handles on a working segment's left and right boundaries. The right handle resizes the issue and moves the entire right tail in sync (Accordion / Ripple). The left handle resizes the issue by consuming the preceding gap, stopping at the previous neighbor. The minimum duration is 10 minutes. A contrasting outline highlights the active block.
_Avoid_: Freeform canvas, Elastic collision

### Integration and agents

**Local Agent API**:
An embedded HTTP REST server on loopback (`127.0.0.1`, usually port `8765`). External AI agents and scripts can manage free LocalLogs, read Jira worklogs by date or Issue, and atomically replace a complete DayDraft. The API does not submit worklogs to Jira.
_Avoid_: Cloud webhook, Remote backend, Headless CLI

**Agent Day Snapshot**:
A complete proposed DayDraft saved by an agent in one operation: date, revision of the state it read, and all Segments referencing existing LocalLogs. It replaces a draft rather than streaming interval-editing commands.
_Avoid_: Patch day, Send day, Segment command stream
