# 02. Визуальные ручки и перетаскивание на TimelineTrackBar (Ticket 02)

Status: resolved

## Описание
В `lib/ui/timeline_track_bar.dart`:
1. Добавить ручки (drag handles) на левую и правую границы каждого рабочего сегмента:
   - Ширина хитбокса ~10–12 px.
   - Курсор: `SystemMouseCursors.resizeLeftRight` (или `resizeColumn`).
2. Состояние `hoveredSegmentId` и `activeDragSegmentId`:
   - При наведении курсора на ручку или во время drag сегмент визуально подсвечивается акцентной рамкой (`border: Border.all(color: AppColors.accent(isDark), width: 2)`), чтобы однозначно идентифицировать изменяемую задачу.
3. Коллбэки:
   - `onResizeSegmentRight(Segment segment, int newDurationSeconds)`
   - `onResizeSegmentLeft(Segment segment, DateTime newStartUtc)`
4. Отображение подсказки (tooltip/badge) в реальном времени при drag (например: «10:00 — 11:45 (1 ч 45 мин)»).
5. Widget-тесты ручек и ховера.
