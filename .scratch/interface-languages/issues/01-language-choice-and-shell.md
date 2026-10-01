# 01: Language selection, persistence, and shell

**What to build:** The user switches language in the Settings header, immediately sees the translated shell, and retains the choice between launches. Rules are in the [specification](../spec.md).

**Blocked by:** None (can start immediately).

**Status:** complete

- [x] A new installation chooses Russian for Russian Windows and English for other languages; an upgrade preserves Russian.
- [x] System default / Russian / English are available beside the theme; manual selection persists.
- [x] Switching preserves navigation and work; read-only mode prohibits changes.
- [x] A temporary database and widget scenario verify selection, restart, and shell.

## Comments

2026-10-01: Implemented and verified. Checks, independent review, Windows build, and limitations are recorded in the [report](../verification.md). Production Jira was not used.
