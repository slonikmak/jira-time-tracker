# 01. Алгоритм выталкивания волной (Ripple Push) и интенты зазоров в AppState

Status: resolved

## Описание
Реализовать и покрыть модульными тестами математику выталкивания волной и интентов управления промежутками:
1. `canShiftRight(fromUtc, deltaSeconds)`: проверяет, не упирается ли сдвиг вправо в неизменяемую запись Jira (`ImportedWorklog`).
2. `shiftSegmentsRight({required DateTime afterUtc, required int deltaSeconds})`: каскадно сдвигает все сегменты правее `afterUtc` вправо на `deltaSeconds`, сохраняя их длительность.
3. `snapGap(Break gap)`: схлопывает зазор, сдвигая правую цепочку сегментов влево в стык к левому интервалу.
4. `fillGapWithLeftSegment(Break gap)`: расширяет левый сегмент на всю величину зазора.
5. `setGapDuration({required Break gap, required int newDurationSeconds})`: выталкивает/подтягивает правую цепочку сегментов под заданную длительность зазора.
6. `toggleGapLunch(Break gap)`: переключает тип зазора (обед / перерыв) с сохранением в БД.
7. Unit-тесты всех граничных случаев (упор в Jira, краевые зазоры, каскадный сдвиг цепочки).
