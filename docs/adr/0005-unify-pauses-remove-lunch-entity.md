# ADR-0005: Removing lunch as a separate entity and unifying breaks

## Status

Accepted

## Context

The original day model distinguished lunch (`BreakKind.lunch`) from short breaks (`BreakKind.short`). This distinction affected:

- The UI: special highlighting (`AppColors.warn`), a restaurant icon (`Icons.restaurant`), badges, and **Lunch** tooltips.
- `GapActionsDialog`: a **Make lunch / break** toggle.
- User experience: unnecessary mental overhead and artificial entities when users mainly needed work intervals and the free time between them.

User requirement, translated:

> Remove the concept of lunch. Everything is an ordinary break; automatic day building just creates one longer break.

## Decision

1. **A single UI break entity:**
   - Display all breaks identically in `TimelineTrackBar`, `DayScreen` schedule cards, and `GapActionsDialog`.
   - Use one break icon (`Icons.coffee`), neutral gray text (`AppColors.muted`), one timeline color (`AppColors.trackBreak`), and the label **Break**.
2. **Simpler gap actions (`GapActionsDialog`):**
   - Remove the **Make lunch / Make break** toggle.
   - Retain only interval geometry operations: **Close gap**, **Fill gap with the previous issue**, and **Set break duration**, with ripple pushing of subsequent issues.
3. **Retain appropriate break planning in automatic builds:**
   - `DayBuilder.buildSmartDay` still schedules one longer mid-day break (30–45 minutes) and several short breaks (5–10 minutes).
   - Create the long break as an ordinary `BreakKind.short`, without privileged status or special visual markers.
4. **Backward compatibility:**
   - Retain `BreakKind.lunch` and SQLite settings fields for existing local databases. All UI and business logic treats gaps as ordinary breaks.

## Consequences

- The interface is clearer and simpler, with less visual noise and fewer break-type controls.
- Users retain control over every break's duration and position through timeline drag handles and gap actions.
