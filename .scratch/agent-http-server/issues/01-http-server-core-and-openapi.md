Status: resolved

# Ticket 01: Ядро HTTP-сервера и эндпоинты справки (/api/help, /api/openapi.json)

## Описание
Создать модуль `lib/agent_api_server.dart`, реализующий локальный встроенный HTTP-сервер на базе `dart:io` (`HttpServer`):
1. Привязка к `InternetAddress.loopbackIPv4` (`127.0.0.1`), порт 8765 (с fallback при занятости).
2. Обработка CORS preflight (OPTIONS) и добавление CORS-заголовков ко всем ответам.
3. Парсинг JSON-тел запросов с обработкой ошибок невалидного JSON.
4. Реализация `GET /api/help` с читаемой Markdown-справкой по всем маршрутам и примерами `curl`.
5. Реализация `GET /api/openapi.json` с валидной схемой OpenAPI 3.0.0.
6. Unit-тесты запуска, остановки сервера и вызова help/openapi эндпоинтов в `test/agent_api_server_test.dart`.
