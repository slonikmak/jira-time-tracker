const defaultAgentDayRuleEn =
    '''Build the day from work that was actually done. Do not invent tasks or descriptions. Link every interval to its source log; preserve the source's total duration whenever possible.

The start_minutes fields define the day-start range in minutes after midnight; total_duration_seconds defines the full day duration, including breaks. Choose values within these ranges. The lunch_start_minutes and lunch_duration_seconds fields define the start and duration of the long break; a duration range of 0–0 disables it. The short_break_count and short_break_duration_seconds fields define the number and duration of short breaks. Place breaks outside working intervals.

Account for existing Jira worklogs and do not create them again. Do not make working intervals shorter than 15 minutes. If the work facts and settings are incompatible, explain the conflict to the user instead of inventing time.''';

String defaultAgentDayRuleForLanguage(String languageCode) =>
    languageCode == 'ru' ? defaultAgentDayRuleRu : defaultAgentDayRuleEn;

bool isDefaultAgentDayRule(String text) =>
    text == defaultAgentDayRuleRu || text == defaultAgentDayRuleEn;

String agentSkillPrompt(String baseUrl, {String languageCode = 'ru'}) =>
    languageCode == 'ru'
    ? _agentSkillPromptRu(baseUrl)
    : _agentSkillPromptEn(baseUrl);

String agentApiHelp(String baseUrl, {String languageCode = 'ru'}) =>
    languageCode == 'ru' ? _agentApiHelpRu(baseUrl) : _agentApiHelpEn(baseUrl);

String _agentSkillPromptEn(String baseUrl) =>
    '''# Skill: Using the local Jira Time Tracker

The local REST API is available at `$baseUrl`.

## Rules
- Only the user submits final worklogs to Jira through the UI.
- A `LocalLog` is a work source; a `Segment` is an individual planned Jira worklog.
- Every segment must contain the `source_log_id` of an existing queue log. Multiple segments may refer to one source within the same day.
- A source must be stopped, unsubmitted, and unassigned to a draft for another date. To use work on different dates, first split its queue log with `POST /api/logs/{id}/split`.
- All segments for a day must fall entirely within the specified date. Working segments may overlap; breaks are calculated automatically outside working intervals.

## Search and queue
- `GET /api/issues?q=...` searches locally by key, summary, and status.
- `GET /api/issues/{key}` reads current Jira text fields, all available comments, and attachment metadata.
- `GET /api/issues/{key}/attachments/{id}` downloads an attachment separately using an ID from that list.
- `GET /api/issues/{key}/worklogs` reads all available Jira worklogs for an issue, including other authors' entries; `is_mine` identifies yours.
- `GET /api/logs?q=...&issue_key=...&availability=...` returns logs with `availability` (`free`, `running`, `in_draft`) and `draft_date`.
- `GET /api/quick-issues` returns quick issues for the active connection with local `note` descriptions; `POST /api/quick-issues`, `PATCH` and `DELETE /api/quick-issues/{issueId}` update the list.
- `POST /api/logs` and `POST /api/logs/merge` accept only known local issues or references verified through Jira; an unknown reference is never created as an offline fallback.
- The agent may create, edit, delete, split, and merge free queue logs.

## Building a day
1. Before every build, call `GET /api/day-settings`. Its single response contains current numeric `settings` ranges and the user-editable text `rule`. Apply both when planning; do not rely on an old copy of the rule.
2. Call `GET /api/day?date=YYYY-MM-DD` for fresh Jira worklogs and the current draft. If Jira is unavailable, stop and report the error.
3. If a draft exists, keep its top-level `revision`.
4. Call `POST /api/day` with the complete set of segments. Every segment must refer to its `source_log_id`; `issue_key` is optional and, if supplied, must match the source's issue.
5. For an existing draft, include `base_revision`. A `409` response indicates an editing conflict: reread the date, reconcile the changes, and submit the snapshot again.

```json
{
  "date": "2026-09-17",
  "base_revision": "revision-from-GET",
  "segments": [
    {"source_log_id": "uuid-1", "start": "09:00", "duration_minutes": 30, "description": "Analysis"},
    {"source_log_id": "uuid-1", "start": "09:45", "duration_minutes": 30, "description": "Implementation"}
  ]
}
```

For the full contract, call `GET /api/help` or `GET /api/openapi.json`.
''';

String _agentApiHelpEn(String url) =>
    '''# Jira Time Tracker Local Agent API

A local REST API for integrating AI agents (Claude, Antigravity, MCP servers, and scripts).

Base URL: `$url`

## Model and rules
- A `LocalLog` is a work source; a `Segment` is an individual worklog that the user can submit to Jira.
- Every segment in `POST /api/day` must contain `source_log_id`. Multiple segments may refer to one source within the same day.
- Working segments may overlap each other and existing Jira worklogs; each segment remains a separate worklog after UI confirmation. Breaks do not overlap working intervals.
- A source must be stopped, unsubmitted, and unassigned to an active draft for another date. To spread work across dates, first split the source with `POST /api/logs/{id}/split`.
- The agent replaces the entire draft. Before writing, call `GET /api/day?date=YYYY-MM-DD`; if a `draft` exists, pass its top-level `revision` as `base_revision`. A `409` response requires rereading the day and rebuilding the snapshot.
- GET/POST `/api/day` load Jira worklogs for the specified date; a Jira error returns `502`.
- Only the user submits final worklogs to Jira through the application.

## Search and queue
- `GET /api/issues?q=text` searches the local catalog by key, summary, and status. No remote fuzzy search is performed.
- `GET /api/issues/PROJ-123` returns the current Jira issue: description text, all available comments, and attachment metadata with `download_path`.
- `GET /api/issues/PROJ-123/attachments/10001` returns attachment bytes; obtain the ID from the issue. The application does not save the file to disk.
- `GET /api/issues/PROJ-123/worklogs` returns all available Jira worklogs for an issue, including other authors' entries; `is_mine` identifies the current account's entries.
- `GET /api/logs?q=text&issue_key=PROJ-123&availability=free` returns the queue with filters. `availability` is `free`, `running`, or `in_draft`; each entry also contains `draft_date`.
- `POST /api/logs` creates a source for a known local/Jira issue; an unknown issue combined with a Jira error rejects the request without creating a fallback issue.
- `POST /api/logs/{id}/split` and `POST /api/logs/merge` change source queue logs. `PATCH /api/logs/{id}` and `DELETE /api/logs/{id}` manage free logs.
- `GET /api/quick-issues` returns quick issues for the current Jira connection in insertion order. Fields: `issue_id`, `key`, `summary`, `note` (local description); without an active connection, the response is `409`.
- `POST /api/quick-issues` accepts `{"issue_key":"PROJ-123","note":"Hint"}` and adds an issue verified through Jira. Repeated POST preserves its position and updates `note` when provided.
- `PATCH /api/quick-issues/{issueId}` accepts `{"note":"New description"}`; `null` clears the description. `DELETE /api/quick-issues/{issueId}` removes the quick-list reference without deleting the issue or logs.

## Day snapshot
1. Before every build, obtain current ranges and the user rule together with `GET /api/day-settings` and apply both. Then obtain available sources with `GET /api/logs` and day data with `GET /api/day?date=...`.
2. For each segment, supply `source_log_id`, `start` (`HH:MM` or ISO-8601), duration, and description. `issue_key` is optional; if supplied, it must match the source's issue.
3. Supply the complete `segments` array. If GET returned a draft, include its revision as `base_revision`.

```json
{
  "date": "2026-09-17",
  "base_revision": "revision-from-GET",
  "segments": [
    {"source_log_id": "uuid-1", "start": "09:00", "duration_minutes": 30, "description": "Analysis"},
    {"source_log_id": "uuid-1", "start": "09:45", "duration_minutes": 30, "description": "Implementation"}
  ]
}
```

`GET /api/help` contains this reference; `GET /api/openapi.json` returns OpenAPI 3.0.0.
''';

const defaultAgentDayRuleRu =
    '''Собирай день из фактически выполненной работы, не придумывая задачи и описания. Каждый интервал связывай с исходным логом; по возможности сохраняй суммарную длительность источника.

Поля start_minutes задают диапазон начала дня в минутах от полуночи; total_duration_seconds — полную длительность дня вместе с паузами. Выбери значения внутри этих диапазонов. Поля lunch_start_minutes и lunch_duration_seconds задают начало и длительность длинной паузы; длительность 0–0 отключает её. Поля short_break_count и short_break_duration_seconds задают число и длительность коротких пауз. Размести паузы вне работы.

Учитывай существующие записи Jira, не создавай их повторно. Не делай рабочие интервалы короче 15 минут. Если факты работы и настройки несовместимы, объясни конфликт пользователю вместо выдумывания времени.''';

String _agentSkillPromptRu(String baseUrl) =>
    '''# Навык: Взаимодействие с локальным Jira Time Tracker

Локальный REST API доступен по адресу `$baseUrl`.

## Правила
- Финальные worklogs в Jira отправляет только пользователь из UI.
- `LocalLog` — источник работы; `Segment` — отдельный планируемый Jira worklog.
- Каждый segment должен содержать `source_log_id` существующего queue log. Несколько сегментов могут ссылаться на один источник в пределах одного дня.
- Источник должен быть остановлен, не отправлен и не занят черновиком другой даты. Для разных дат раздели исходный лог в очереди через `POST /api/logs/{id}/split`.
- Сегменты одного дня должны полностью попадать в указанную дату. Пересечения рабочих сегментов разрешены; паузы формируются автоматически вне работы.

## Поиск и очередь
- `GET /api/issues?q=...` ищет локально по key, summary и status.
- `GET /api/issues/{key}` читает актуальные текстовые поля, все доступные комментарии и список вложений Jira.
- `GET /api/issues/{key}/attachments/{id}` отдельно скачивает вложение по ID из списка.
- `GET /api/issues/{key}/worklogs` читает все доступные записи Jira по тикету, включая записи других авторов; `is_mine` отмечает ваши.
- `GET /api/logs?q=...&issue_key=...&availability=...` возвращает логи с `availability` (`free`, `running`, `in_draft`) и `draft_date`.
- `GET /api/quick-issues` возвращает быстрые задачи активного подключения с локальными описаниями `note`; `POST /api/quick-issues`, `PATCH` и `DELETE /api/quick-issues/{issueId}` меняют этот список.
- `POST /api/logs` и `POST /api/logs/merge` принимают только известные локальные задачи или refs, которые удалось подтвердить через Jira; неизвестный ref не создаётся как offline fallback.
- Агент может создавать, редактировать, удалять, делить и объединять свободные queue logs.

## Сборка дня
1. Перед каждой сборкой вызови `GET /api/day-settings`. В одном ответе находятся актуальные числовые диапазоны `settings` и редактируемое пользователем текстовое `rule`. Применяй оба при планировании; не полагайся на старую копию правила.
2. Вызови `GET /api/day?date=YYYY-MM-DD` для свежих worklogs Jira и текущего draft. Если Jira недоступна, остановись и сообщи об ошибке.
3. Если draft существует, сохрани его top-level `revision`.
4. Вызови `POST /api/day`, передав весь набор segments целиком. Каждый segment должен ссылаться на свой `source_log_id`; `issue_key` необязателен и, если передан, должен соответствовать задаче источника.
5. При существующем draft передай `base_revision`. Ответ `409` означает конфликт правок: перечитай дату, объедини изменения и отправь snapshot заново.

```json
{
  "date": "2026-09-17",
  "base_revision": "revision-from-GET",
  "segments": [
    {"source_log_id": "uuid-1", "start": "09:00", "duration_minutes": 30, "description": "Разбор"},
    {"source_log_id": "uuid-1", "start": "09:45", "duration_minutes": 30, "description": "Реализация"}
  ]
}
```

Для полного контракта вызови `GET /api/help` или `GET /api/openapi.json`.
''';

String _agentApiHelpRu(String url) =>
    '''# Jira Time Tracker Local Agent API

Локальный REST API для интеграции AI-агентов (Claude, Antigravity, MCP-серверов и скриптов).

Базовый URL: `$url`

## Модель и правила
- `LocalLog` — источник работы; `Segment` — отдельный worklog, который пользователь сможет отправить в Jira.
- Каждый segment в `POST /api/day` обязан содержать `source_log_id`. Несколько segments могут ссылаться на один источник в пределах одного дня.
- Рабочие segments и существующие Jira worklogs могут пересекаться по времени; каждый segment останется отдельным worklog после подтверждения в UI. Паузы не пересекаются с работой.
- Источник должен быть остановлен, не отправлен и не занят активным черновиком другой даты. Чтобы разнести работу на разные даты, сначала раздели source через `POST /api/logs/{id}/split`.
- Агент заменяет черновик целиком. Перед записью вызови `GET /api/day?date=YYYY-MM-DD`; если `draft` существует, передай его top-level `revision` как `base_revision`. Ответ `409` требует перечитать день и собрать snapshot заново.
- Jira worklogs в GET/POST `/api/day` загружаются для указанной даты; при ошибке Jira возвращается `502`.
- Финальную отправку worklogs в Jira всегда выполняет пользователь в приложении.

## Поиск и очередь
- `GET /api/issues?q=текст` — поиск по локальному каталогу: key, summary и status. Удалённый fuzzy search не выполняется.
- `GET /api/issues/PROJ-123` — актуальная карточка Jira: текст описания, все доступные комментарии и метаданные вложений с `download_path`.
- `GET /api/issues/PROJ-123/attachments/10001` — бинарное содержимое вложения; ID берётся из карточки. Файл не сохраняется приложением на диск.
- `GET /api/issues/PROJ-123/worklogs` — все доступные worklogs Jira по задаче, включая других авторов; `is_mine` отмечает записи текущего аккаунта.
- `GET /api/logs?q=текст&issue_key=PROJ-123&availability=free` — очередь и фильтры. `availability`: `free`, `running` или `in_draft`; запись также содержит `draft_date`.
- `POST /api/logs` создаёт source для известной локальной/Jira-задачи; при неизвестной задаче и ошибке Jira запрос отклоняется, fallback-задача не создаётся.
- `POST /api/logs/{id}/split` и `POST /api/logs/merge` меняют исходные логи очереди. `PATCH /api/logs/{id}` и `DELETE /api/logs/{id}` управляют свободными логами.
- `GET /api/quick-issues` возвращает быстрые задачи текущего Jira-подключения в порядке добавления. Поля: `issue_id`, `key`, `summary`, `note` (локальное описание); без активного подключения ответ `409`.
- `POST /api/quick-issues` принимает `{"issue_key":"PROJ-123","note":"Подсказка"}` и добавляет проверенную через Jira задачу. Повторный POST сохраняет позицию и обновляет `note`, если оно передано.
- `PATCH /api/quick-issues/{issueId}` принимает `{"note":"Новое описание"}`; `null` очищает описание. `DELETE /api/quick-issues/{issueId}` убирает ссылку из быстрого списка, не удаляя задачу и логи.

## Snapshot дня
1. Перед каждой сборкой получи актуальные диапазоны и пользовательское правило одним запросом `GET /api/day-settings` и используй оба. Затем получи доступные источники через `GET /api/logs` и данные дня через `GET /api/day?date=...`.
2. Для каждого segment передай `source_log_id`, `start` (`HH:MM` или ISO-8601), длительность и описание. `issue_key` необязателен; если передан, он должен совпадать с задачей источника.
3. Передай массив `segments` целиком. Если GET вернул draft, включи его revision в `base_revision`.

```json
{
  "date": "2026-09-17",
  "base_revision": "revision-from-GET",
  "segments": [
    {"source_log_id": "uuid-1", "start": "09:00", "duration_minutes": 30, "description": "Разбор"},
    {"source_log_id": "uuid-1", "start": "09:45", "duration_minutes": 30, "description": "Реализация"}
  ]
}
```

`GET /api/help` содержит эту справку; `GET /api/openapi.json` возвращает OpenAPI 3.0.0.
''';
