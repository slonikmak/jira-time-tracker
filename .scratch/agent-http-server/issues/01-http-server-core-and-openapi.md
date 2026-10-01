Status: resolved

# Ticket 01: HTTP server core and help endpoints (/api/help, /api/openapi.json)

## Description
Create `lib/agent_api_server.dart`, an embedded local HTTP server based on `dart:io` (`HttpServer`):
1. Bind to `InternetAddress.loopbackIPv4` (`127.0.0.1`), port 8765 with fallback when occupied.
2. Handle CORS preflight (OPTIONS) and add CORS headers to all responses.
3. Parse JSON request bodies and handle invalid JSON errors.
4. Implement `GET /api/help` with readable Markdown help covering every route and `curl` examples.
5. Implement `GET /api/openapi.json` with a valid OpenAPI 3.0.0 schema.
6. Unit-test server startup, shutdown, and help/openapi calls in `test/agent_api_server_test.dart`.
