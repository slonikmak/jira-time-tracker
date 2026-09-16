# 03. Интеграция с таймлайном и расписанием дня (TimelineTrackBar & DayScreen)

Status: resolved

## Описание
1. `TimelineTrackBar`:
   - Добавить в `_TrackItem` ссылку на `Break` (если `isBreak == true`).
   - Добавить коллбэк `onEditBreak: (Break breakItem)?`.
   - Для элементов пауз добавить визуальную реакцию (курсор `SystemMouseCursors.click`, InkWell с onTap).
2. `DayScreen`:
   - В `_buildBreakCard` сделать карточку кликабельной (`InkWell`) и добавить справа кнопку `IconButton` «Редактировать интервал» (иконка `Icons.edit_outlined`).
   - Передать `onEditBreak` в `TimelineTrackBar`.
   - Метод `_openEditBreakDialog(BuildContext context, Break breakItem)` открывает `EditBreakDialog` и передает в него данные о соседях и коллбэки сохранения/удаления.
3. Прогон всех тестов и линтеров.
