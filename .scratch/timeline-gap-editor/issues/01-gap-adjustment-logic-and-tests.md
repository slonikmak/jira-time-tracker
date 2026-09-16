# 01. Логика сдвига смежных границ при изменении промежутка (AppState & DayBuilder)

Status: resolved

## Описание
Реализовать в `AppState` бизнес-логику применения изменений к промежутку (`updateBreakGap` и `deleteBreakGap`):
1. Поиск левого ($L$) и правого ($R$) соседей для зазора: это могут быть `Segment`, `ImportedWorklog` или граница дня.
2. Проверка валидности новых границ:
   - $newStart < newEnd$.
   - Если $L$ — `Segment`, его новая длительность $\ge 60$ сек.
   - Если $L$ — `ImportedWorklog`, $newStart == L.endUtc$.
   - Если $R$ — `Segment`, его новая длительность $\ge 60$ сек.
   - Если $R$ — `ImportedWorklog`, $newEnd == R.startUtc$.
3. Применение изменений к базе данных (`store.updateSegment`, `store.updateDayDraft`, сохранение `breaks`) и вызов `_revalidateCurrentPlan()`, `notifyListeners()`.
4. Реализация операции смыкания `deleteBreakGap`.
5. Покрытие unit-тестами.
