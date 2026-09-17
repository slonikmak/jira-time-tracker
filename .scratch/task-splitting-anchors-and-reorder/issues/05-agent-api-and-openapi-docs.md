# Issue 05: Agent HTTP API: поддержка фиксированного времени, эндпоинты split/merge и документация

## Зависит от:
- Issue 01 (Методы `splitLog`, `mergeLogs` в AppState)

## Описание задачи:
1. **Обновление эндпоинтов существующих логов**:
   - `POST /api/logs`: поддержка опционального поля `"fixed_start_time": "11:00"` (валидация формата HH:mm).
   - `GET /api/logs/unsubmitted`: вывод поля `"fixed_start_time"` в объектах логов.
2. **Новые эндпоинты для Split и Merge**:
   - `POST /api/logs/{id}/split`:
     - Входные данные: `{ "part1_minutes": 45, "part1_description": "...", "part2_description": "..." }` (или `part1_seconds`).
     - Ответ: `201 Created` со списком двух созданных логов.
   - `POST /api/logs/merge`:
     - Входные данные: `{ "source_log_ids": ["uuid1", "uuid2"], "target_issue_key": "PROJ-123", "description": "..." }`.
     - Ответ: `200 OK` с объектом объединенного лога.
3. **Обновление эндпоинта дня**:
   - `POST /api/day`: поддержка `"is_fixed": true` и `"fixed_start_time": "11:00"` для элементов массива `segments`.
   - `GET /api/day`: выдача `is_fixed` в сегментах.
4. **Документация и OpenAPI**:
   - Обновить `GET /api/help` с примерами запросов на split, merge и фиксацию времени.
   - Обновить `GET /api/openapi.json` схемами новых параметров и эндпоинтов.
   - Обновить промпт скилла в `AgentApiServer.generateSkillPrompt(...)`.

## Критерии приемки:
- Тесты на `POST /api/logs` с `fixed_start_time`.
- Тесты на `POST /api/logs/{id}/split` (успех и валидация).
- Тесты на `POST /api/logs/merge` (успех и валидация).
- Проверка генерации OpenAPI и текста помощи.
- `flutter analyze` — 0 предупреждений.
