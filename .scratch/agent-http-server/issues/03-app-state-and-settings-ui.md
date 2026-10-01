Status: resolved

# Ticket 03: AppState integration and Settings section for copying an agent skill

## Description
1. Manage the `AgentApiServer` lifecycle in `AppState`:
   - Start automatically during application initialization.
   - Stop cleanly on shutdown.
   - Expose `apiServerUrl` (for example, `http://127.0.0.1:8765`).
2. Add a section to the Settings dialog (`SettingsDialog`):
   - Local server status (active/port).
   - Server address field.
   - Copy agent instruction button: copy ready-made Markdown system-prompt/skill text describing interaction with the tracker through curl/HTTP.
3. Integration tests and UI verification.
