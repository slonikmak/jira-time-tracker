# Issue 01: База данных, модели и базовые операции Split & Merge в AppState

## Блокирует:
- Issue 02 (Алгоритм сборщика дня)
- Issue 03 (UI экрана «Работа»)
- Issue 04 (UI экрана «День»)
- Issue 05 (Agent API)

## Описание задачи:
1. **SQLite схема (`lib/local_store.dart`)**:
   - Миграция таблицы `local_logs`: добавить колонку `fixed_start_time TEXT`.
   - Миграция таблицы `segments`: добавить колонку `is_fixed INTEGER NOT NULL DEFAULT 0`.
   - Обеспечить обратную совместимость при открытии существующей БД через `PRAGMA table_info`.
2. **Модели (`lib/models.dart`)**:
   - `LocalLog`: добавить `String? fixedStartTime`.
   - `Segment`: добавить `bool isFixed`.
   - Обновить `toMap`, `fromMap`, `copyWith`.
3. **Методы в `LocalStore` / `AppState`**:
   - `splitLog({required String logId, required int part1DurationSeconds, String? part1Description, String? part2Description})`: разбивает лог на 2, сохраняя дату и задачу.
   - `mergeLogs({required List<String> logIds, String? targetIssueId, String? description})`: объединяет несколько логов в один с суммированием длительности.
   - `splitSegment({required String segmentId, required int splitOffsetSeconds, String? part1Description, String? part2Description})`: разрезает сегмент дня на два последовательных сегмента.
   - `mergeSegments({required String segmentId1, required String segmentId2})`: объединяет два сегмента дня.
   - `toggleSegmentFixed(String segmentId)`: переключает флаг `isFixed`.
   - Мягкая отвязка при удалении сегментов из черновика.

## Критерии приемки:
- Тесты на корректную миграцию БД SQLite без потери данных.
- Юнит-тесты на `splitLog`, `mergeLogs`, `splitSegment`, `mergeSegments`.
- `flutter analyze` без ошибок.
