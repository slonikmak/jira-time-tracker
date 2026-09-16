# 01. Математика сдвигов границ в AppState (Ticket 01)

Status: resolved

## Описание
Реализовать в `AppState` методы прямого манипулирования границами сегментов:
1. `resizeSegmentRight(Segment segment, int newDurationSeconds)`:
   - Clamping `newDurationSeconds >= 600` (минимум 10 минут).
   - Вычисление $\Delta t = newDurationSeconds - segment.durationSeconds$.
   - Обновление текущего сегмента: `durationSeconds = newDurationSeconds`.
   - Если $\Delta t > 0$: проверка упора в `ImportedWorklog` через `canShiftSegmentsRight`. Если есть упор, сдвигать на максимально возможное дельта-время либо бросать ошибку/ограничивать сдвиг.
   - Сдвиг всех сегментов справа (`s.startUtc >= segment.endUtc`) на $\Delta t$.
   - Сдвиг всех `Breaks` справа (обеды) на $\Delta t$.
   - Авторасширение `DayDraft.endUtc`, если крайний сегмент вышел за границу.
2. `resizeSegmentLeft(Segment segment, DateTime newStartUtc)`:
   - Определение левого соседа (предыдущий сегмент или `ImportedWorklog` или `DayDraft.startUtc`).
   - Ограничение слева: `minStart = max(leftNeighbor.endUtc, dayDraft.startUtc)`. Если `newStartUtc < minStart`, клампим в `minStart`.
   - Ограничение справа: `maxStart = segment.endUtc.subtract(Duration(minutes: 10))`. Если `newStartUtc > maxStart`, клампим в `maxStart`.
   - Вычисление новой длительности: `newDurationSeconds = segment.endUtc.difference(newStartUtc).inSeconds`.
   - Обновление сегмента `segment.copyWith(startUtc: newStartUtc, durationSeconds: newDurationSeconds)`.
   - Пересчёт или удаление зазора перед сегментом.
3. Unit-тесты всех граничных условий и упоров.
